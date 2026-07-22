`default_nettype none
`timescale 1ps/1ps

module in_fifo #(
	parameter integer NUM_SLOTS = 64, // sized buffer to mmeory available (spi is killing the input)
	parameter integer MAT_W = 128,
	parameter integer DATA_W = 32
)(
	`ifdef USE_POWER_PINS
    inout VCCD1,
    inout VSSD1,
	`endif
	input wire clk,
	input wire rstn,

	input wire i_wr_valid,
	input wire [DATA_W-1:0] i_wr_data,
	output logic o_wr_ready,

	input wire i_matrix_ready,
	output logic o_matrix_valid,// to array
	output logic [MAT_W-1:0] o_matrix_data, // to array

	output logic [7:0] o_level, // to status regs
	output logic o_empty,
	output logic o_full
);
	localparam integer WORDS = MAT_W / DATA_W; // 4 words per matrix
	localparam integer WORD_W = $clog2(WORDS); // 2
	localparam integer SLOT_W = $clog2(NUM_SLOTS); // 6
	localparam integer LEVEL_W = $clog2(NUM_SLOTS + 1); // 7
	localparam integer FCNT_W = $clog2(WORDS + 1); // 3, counts 0 -WORDS
	localparam integer SRAM_AW = 8;
	localparam logic [WORD_W-1:0] WORD_LAST = WORD_W'(WORDS - 1); // 3
	localparam logic [SLOT_W-1:0] SLOT_LAST = SLOT_W'(NUM_SLOTS - 1);
	localparam logic [FCNT_W-1:0] FCNT_DONE = FCNT_W'(WORDS); // 4
	localparam logic [FCNT_W-1:0] FCNT_LAST_ISS = FCNT_W'(WORDS-1); // 3

	logic full, empty, wr_ready, matrix_valid;
	logic accept, last_word, push, pop;
	logic read_issue, cap_en, fetch_done;

	logic [WORD_W-1:0] wr_word_r;
	logic [SLOT_W-1:0] wr_slot_r;

	assign wr_ready = !full; // backpressure; never on busy
	assign accept = i_wr_valid && wr_ready;
	assign last_word = (wr_word_r == WORD_LAST);
	assign push = accept && last_word; // word 4 revcied

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			wr_word_r <= '0;
			wr_slot_r <= '0;
		end else if (accept) begin
			wr_word_r <= wr_word_r + 1'b1; // 3 to 0 wrap
			if (last_word) begin
				wr_slot_r <= (wr_slot_r == SLOT_LAST) ? '0 : wr_slot_r + 1'b1;
			end
		end
	end

	logic [LEVEL_W-1:0] level_r; // check occupancy
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			level_r <= '0;
		end else if (push && !pop) begin
			level_r <= level_r + 1'b1;
		end else if (pop && !push) begin
			level_r <= level_r - 1'b1;
		end
	end

	assign full = (level_r == LEVEL_W'(NUM_SLOTS));
	assign empty = (level_r == '0);

	// prefetch head slots 4 words into hold_r
	// valid held till job is compelte
	typedef enum logic [1:0] {
		RD_EMPTY = 2'b00,
		RD_FETCH = 2'b01,
		RD_VALID = 2'b10
	} rstate_t;
	rstate_t current_state, next_state;

	logic [FCNT_W-1:0] fcnt_r;
	logic [SLOT_W-1:0] rd_slot_r;
	wire [WORD_W-1:0] rd_word = fcnt_r[WORD_W-1:0];

	assign read_issue = (current_state == RD_FETCH) && (fcnt_r <= FCNT_LAST_ISS);
	assign cap_en = (current_state == RD_FETCH) && (fcnt_r != '0); // sram read latency = 1
	assign fetch_done = (current_state == RD_FETCH) && (fcnt_r == FCNT_DONE);
	assign matrix_valid = (current_state == RD_VALID);
	assign pop = matrix_valid && i_matrix_ready;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			fcnt_r <= '0;
		end else if (current_state != RD_FETCH) begin
			fcnt_r <= '0;
		end else if (fcnt_r < FCNT_DONE) begin
			fcnt_r <= fcnt_r + 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_slot_r <= '0;
		end else if (pop) begin
			rd_slot_r <= (rd_slot_r == SLOT_LAST) ? '0 : rd_slot_r + 1'b1;
		end
	end

	always_comb begin
		next_state = current_state;
		case (current_state)
			RD_EMPTY: begin
				if (!empty) begin
					next_state = RD_FETCH;
				end
			end
			RD_FETCH: begin
				if (fetch_done) begin
					next_state = RD_VALID;
				end
			end
			RD_VALID: begin
				if (pop) begin // start on next matrix if its waiting
					next_state = (level_r > LEVEL_W'(1)) ? RD_FETCH : RD_EMPTY;
				end
			end
			default: next_state = RD_EMPTY;
		endcase
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			current_state <= RD_EMPTY;
		end else begin
			current_state <= next_state;
		end
	end

	// shift register
	// word0 enters at [31;0] after 4 shift
	logic [MAT_W-1:0] hold_r;
	wire [DATA_W-1:0] rd_data;

	always_ff @(posedge clk) begin
		if (cap_en) begin
			hold_r <= {rd_data, hold_r[MAT_W-1:DATA_W]};
		end
	end

	wire [SRAM_AW-1:0] wr_addr = {wr_slot_r, wr_word_r};
	wire [SRAM_AW-1:0] rd_addr = {rd_slot_r, rd_word};

	wire csb0, web0, csb1, p0_we;
	assign p0_we = 1'b1;
	assign csb0 = ~accept; // low = selected
	assign web0 = ~p0_we; // low = wr
	assign csb1 = ~read_issue;

	sky130_sram_1kbyte_1rw1r_32x256_8 sram (
		`ifdef USE_POWER_PINS
		.vccd1(VCCD1),
		.vssd1(VSSD1),
		`endif
		// port 0: read/write
		.clk0(clk),
		.csb0(csb0),
		.web0(web0),
		.wmask0(4'hF),
		.addr0(wr_addr),
		.din0(i_wr_data),
		.dout0(),
		// port 1: read
		.clk1(clk),
		.csb1(csb1),
		.addr1(rd_addr),
		.dout1(rd_data)
	);

	assign o_wr_ready = wr_ready;
	assign o_empty = empty;
	assign o_full = full;
	assign o_matrix_valid = matrix_valid;
	assign o_matrix_data = hold_r;
	assign o_level = {{(8-LEVEL_W){1'b0}}, level_r};

endmodule
`default_nettype wire
