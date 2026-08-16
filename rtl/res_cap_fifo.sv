`default_nettype none
`timescale 1ps/1ps

module res_cap_fifo #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	parameter integer BEAT_W = 32, // AXI master data width
	parameter integer JOBS = 2,
	
	localparam integer RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 18
	localparam integer ROWS = JOBS * MATRIX_SIZE, // rows of capacity
	localparam integer LVL_W = $clog2(ROWS + 1)
)(
	input wire clk,
	input wire rstn,
	input wire [MATRIX_SIZE-1:0] i_result_valid, // one per column
	input wire [MATRIX_SIZE*RESULT_WIDTH-1:0] i_result_data,
	input wire i_reserve,
	output wire o_room,
	input wire rd_en,
	output wire [BEAT_W-1:0] o_rdata, 
	output wire o_valid,
	output wire [LVL_W-1:0] o_level,
	output wire o_overflow
);
	localparam integer ROW_W = MATRIX_SIZE * RESULT_WIDTH; // 72
	localparam integer PTR_W = $clog2(ROWS);
	localparam integer TILE_BITS = MATRIX_SIZE * ROW_W; // 288
	localparam integer TILE_BEATS = TILE_BITS / BEAT_W; // 9
	localparam integer BI_W = $clog2(TILE_BEATS);

	logic [ROW_W-1:0] mem [0:ROWS-1];
	logic [PTR_W-1:0] wr_ptr [0:MATRIX_SIZE-1];
	logic [LVL_W-1:0] level_r;

	wire full = (level_r == LVL_W'(ROWS));
	wire row_valid = i_result_valid[MATRIX_SIZE-1];
	wire push = row_valid && !full;

	genvar c;
	generate
		for (c = 0; c < MATRIX_SIZE; c = c + 1) begin : gen_col
			wire signed [RESULT_WIDTH-1:0] din = signed'(i_result_data[RESULT_WIDTH*c +: RESULT_WIDTH]);
			wire wr_en = i_result_valid[c] && !full;

			always_ff @(posedge clk) begin
				if (!rstn) begin
					wr_ptr[c] <= '0;
				end else if (wr_en) begin
					wr_ptr[c] <= (wr_ptr[c] == PTR_W'(ROWS-1)) ? '0 : (wr_ptr[c] + 1'b1);
				end
			end

			always_ff @(posedge clk) begin
				if (wr_en) begin
					mem[wr_ptr[c]][RESULT_WIDTH*c +: RESULT_WIDTH] <= din;
				end
			end
		end
	endgenerate


	logic [ROW_W-1:0] r0_r, r1_r;
	logic r0_v, r1_v;
	logic [BI_W-1:0] beat_idx; // beat index within the current tile

	logic [ROWS-1:0] rd_sel_r;
	logic [ROW_W-1:0] mem_rd;
	always_comb begin
		mem_rd = '0;
		for (int r = 0; r < ROWS; r++) begin
			mem_rd |= {ROW_W{rd_sel_r[r]}} & mem[r];
		end
	end

	function automatic integer max_beat_off;
		integer m;
		begin
			m = 0;
			for (int b = 0; b < TILE_BEATS; b++) begin
				if (((BEAT_W * b) % ROW_W) > m) begin
					m = (BEAT_W * b) % ROW_W;
				end
			end
			max_beat_off = m;
		end
	endfunction
	localparam integer WIN_W = max_beat_off() + BEAT_W; // 96
	localparam integer R1_BITS = WIN_W - ROW_W; // 24

	wire [WIN_W-1:0] win = {r1_r[R1_BITS-1:0], r0_r};
	logic [BEAT_W-1:0] beat_data;
	logic beat_str; // beat crosses into r1
	logic beat_adv; // beat finishes r0

	logic [BEAT_W-1:0] beat_mux [0:TILE_BEATS-1];
	logic [TILE_BEATS-1:0] str_mux, adv_mux;

	genvar i;
	generate
		for (i = 0; i < TILE_BEATS; i = i + 1) begin : gen_beat
			localparam integer OFF = (BEAT_W * i) % ROW_W;
			localparam integer STR = ((OFF + BEAT_W) > ROW_W) ? 1 : 0;
			localparam integer ADV = (((BEAT_W * (i+1)) / ROW_W) > ((BEAT_W * i) / ROW_W)) ? 1 : 0;
			wire sel = (beat_idx == BI_W'(i));
			assign beat_mux[i] = sel ? win[OFF +: BEAT_W] : {BEAT_W{1'b0}};
			assign str_mux[i] = sel && (STR != 0);
			assign adv_mux[i] = sel && (ADV != 0);
		end
	endgenerate

	always_comb begin
		beat_data = '0;
		for (int k = 0; k < TILE_BEATS; k++) begin
			beat_data |= beat_mux[k];
		end
	end
	assign beat_str = |str_mux;
	assign beat_adv = |adv_mux;

	// output register, one beat deep
	logic [BEAT_W-1:0] head_r;
	logic head_valid_r;

	wire beat_ready = r0_v && (!beat_str || r1_v);
	wire consume = head_valid_r && rd_en;
	wire transfer = beat_ready && (!head_valid_r || consume);
	wire row_retire = transfer && beat_adv; // r0 finished

	wire [1:0] staged = {1'b0, r0_v} + {1'b0, r1_v};
	wire can_load = (level_r > LVL_W'(staged));
	wire slot_free = !r0_v || !r1_v || row_retire;
	wire load_en = can_load && slot_free;

	always_ff @(posedge clk) begin
		if (!rstn) begin
			r0_v <= 1'b0;
			r1_v <= 1'b0;
		end else if (row_retire) begin
			if (r1_v) begin
				r0_v <= 1'b1;
				r1_v <= load_en;
			end else begin
				r0_v <= load_en;
				r1_v <= 1'b0;
			end
		end else if (load_en) begin
			if (!r0_v) begin
				r0_v <= 1'b1;
			end else begin
				r1_v <= 1'b1;
			end
		end
	end

	always_ff @(posedge clk) begin
		if (row_retire) begin
			if (r1_v) begin
				r0_r <= r1_r;
				if (load_en) begin
					r1_r <= mem_rd;
				end
			end else begin
				r0_r <= mem_rd;
			end
		end else if (load_en) begin
			if (!r0_v) begin
				r0_r <= mem_rd;
			end else begin
				r1_r <= mem_rd;
			end
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			rd_sel_r <= {{(ROWS-1){1'b0}}, 1'b1};
		end else if (load_en) begin
			rd_sel_r <= {rd_sel_r[ROWS-2:0], rd_sel_r[ROWS-1]};
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			beat_idx <= '0;
		end else if (transfer) begin
			beat_idx <= (beat_idx == BI_W'(TILE_BEATS-1)) ? '0 : (beat_idx + 1'b1);
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			head_valid_r <= 1'b0;
		end else if (transfer) begin
			head_valid_r <= 1'b1;
		end else if (consume) begin
			head_valid_r <= 1'b0;
		end
	end

	always_ff @(posedge clk) begin
		if (transfer) begin
			head_r <= beat_data;
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			level_r <= '0;
		end else if (push && !row_retire) begin
			level_r <= level_r + 1'b1;
		end else if (row_retire && !push) begin
			level_r <= level_r - 1'b1;
		end
	end

	logic overflow_r;
	always_ff @(posedge clk) begin
		if (!rstn) begin
			overflow_r <= 1'b0;
		end else if (row_valid && full) begin
			overflow_r <= 1'b1;
		end
	end

	localparam integer CMT_W = $clog2(ROWS + MATRIX_SIZE + 1);
	logic [CMT_W-1:0] committed_r;

	always_ff @(posedge clk) begin
		if (!rstn) begin
			committed_r <= '0;
		end else begin
			case ({i_reserve, row_retire})
				2'b10: committed_r <= committed_r + CMT_W'(MATRIX_SIZE);
				2'b01: committed_r <= committed_r - 1'b1;
				2'b11: committed_r <= committed_r + CMT_W'(MATRIX_SIZE - 1);
				default: committed_r <= committed_r;
			endcase
		end
	end

	assign o_rdata = head_r;
	assign o_valid = head_valid_r;
	assign o_room = ((committed_r + CMT_W'(MATRIX_SIZE)) <= CMT_W'(ROWS));
	assign o_level = level_r;
	assign o_overflow = overflow_r;

endmodule
`default_nettype wire
