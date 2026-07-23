`default_nettype wire
`timescale 1ps/1ps

module in_fifo #(
	parameter integer NUM_SLOTS = 16, // sized buffer to mmeory available (spi is killing the input)
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
	localparam integer SLOT_W = $clog2(NUM_SLOTS); // 4
	localparam integer LEVEL_W = $clog2(NUM_SLOTS + 1); // 5
	localparam integer FCNT_W = $clog2(WORDS + 1); // 3, counts 0 -WORDS
	localparam integer SRAM_AW = SLOT_W + WORD_W; // 6, must match the 32x64 macro addr width
	localparam logic [WORD_W-1:0] WORD_LAST = WORD_W'(WORDS - 1); // 3
	localparam logic [FCNT_W-1:0] FCNT_DONE = FCNT_W'(WORDS); // 4
	localparam logic [FCNT_W-1:0] FCNT_LAST_ISS = FCNT_W'(WORDS-1); // 3

	logic full, empty, wr_ready, matrix_valid;
	logic accept, last_word, pop;
	logic read_issue, cap_en, fetch_done;

	// slot pointers carry an extra wrap bit; NUM_SLOTS must be a power of 2
	logic [WORD_W-1:0] wr_word_r;
	logic [SLOT_W:0] wr_slot_r;

	assign wr_ready = !full; // backpressure; never on busy
	assign accept = i_wr_valid && wr_ready;
	assign last_word = (wr_word_r == WORD_LAST); // slot commits when word 4 recieved

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			wr_word_r <= '0;
			wr_slot_r <= '0;
		end else if (accept) begin
			wr_word_r <= wr_word_r + 1'b1; // 3 to 0 wrap
			if (last_word) begin
				wr_slot_r <= wr_slot_r + 1'b1; // natural wrap, MSB toggles
			end
		end
	end

	// prefetch head slots 4 words into hold_r
	// valid held till job is compelte
	typedef enum logic [1:0] {
		RD_EMPTY = 2'b00,
		RD_FETCH = 2'b01,
		RD_VALID = 2'b10
	} rstate_t;
	rstate_t current_state, next_state;

	logic [FCNT_W-1:0] fcnt_r;
	logic [SLOT_W:0] rd_slot_r;
	wire [WORD_W-1:0] rd_word = fcnt_r[WORD_W-1:0];

	// occupancy from pointer difference; wrap bits make full/empty exact
	wire [LEVEL_W-1:0] level = wr_slot_r - rd_slot_r;
	assign empty = (wr_slot_r == rd_slot_r);
	assign full = (wr_slot_r == {~rd_slot_r[SLOT_W], rd_slot_r[SLOT_W-1:0]});

	assign read_issue = (current_state == RD_FETCH) && (fcnt_r <= FCNT_LAST_ISS);
	// assign cap_en = (current_state == RD_FETCH) && (fcnt_r != '0); // sram read latency = 1

	(* keep *) logic [WORD_W-1:0] cap_en_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			cap_en_r <= '0;
		end else begin
			cap_en_r <= {WORDS{read_issue}};
		end
	end

	assign fetch_done = (current_state == RD_FETCH) && (fcnt_r == FCNT_DONE);
	assign matrix_valid = (current_state == RD_VALID);
	assign pop = matrix_valid && i_matrix_ready;

	always_ff @(posedge clk) begin
		if (current_state != RD_FETCH) begin
			fcnt_r <= '0;
		end else if (fcnt_r < FCNT_DONE) begin
			fcnt_r <= fcnt_r + 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_slot_r <= '0;
		end else if (pop) begin
			rd_slot_r <= rd_slot_r + 1'b1; // natural wrap, MSB toggles
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
					next_state = (level > LEVEL_W'(1)) ? RD_FETCH : RD_EMPTY;
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

	genvar s;
	generate
		for (s = 0; s< WORDS; s = s+1) begin : gen_hold
			always_ff @(posedge clk) begin
				if (cap_en_r[s]) begin
					hold_r[DATA_W*s +: DATA_W] <= (s == WORDS-1) ? rd_data : hold_r[DATA_W*(s+1) +: DATA_W];
				end
			end
		end
	endgenerate

	wire [SRAM_AW-1:0] wr_addr = {wr_slot_r[SLOT_W-1:0], wr_word_r};
	wire [SRAM_AW-1:0] rd_addr = {rd_slot_r[SLOT_W-1:0], rd_word};

	wire csb0, web0, csb1, p0_we;
	assign p0_we = 1'b1;
	assign csb0 = ~accept; // low = selected
	assign web0 = ~p0_we; // low = wr
	assign csb1 = ~read_issue;

	wire [DATA_W-1:0] dout_not_used;

	(* keep, keep_hierarchy *)
	sky130_sram_256byte_1rw1r_32x64_8 sram (
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
		.dout0(dout_not_used),
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
	assign o_level = {{(8-LEVEL_W){1'b0}}, level};

endmodule
`default_nettype none