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
	wire row_valid = i_result_valid[MATRIX_SIZE-1]; // last column closes the row
	wire push = row_valid && !full;

	genvar c;
	generate
		for (c = 0; c < MATRIX_SIZE; c = c + 1) begin : gen_col
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
					mem[wr_ptr[c]][RESULT_WIDTH*c +: RESULT_WIDTH] <= i_result_data[RESULT_WIDTH*c +: RESULT_WIDTH];
				end
			end
		end
	endgenerate

	function automatic integer max_beat_off;
		max_beat_off = 0;
		for (int b = 0; b < TILE_BEATS; b++) begin
			if (((BEAT_W * b) % ROW_W) > max_beat_off) begin
				max_beat_off = (BEAT_W * b) % ROW_W;
			end
		end
	endfunction

	localparam integer WIN_W = max_beat_off() + BEAT_W; // 96
	localparam integer R1_BITS = WIN_W - ROW_W; // 24

	//row staging
	logic [ROW_W-1:0] stg0_r, stg1_r;
	logic wr_idx, rd_idx;
	logic [1:0] stg_n; // rows staged; 0-2
	logic [PTR_W-1:0] rd_ptr;
	logic [BI_W-1:0] beat_idx;

	// one-hot row select
	logic [ROWS-1:0] rd_sel_r;
	logic [ROW_W-1:0] mem_rd;

	wire load_fire = (stg_n != 2'd2) && (level_r > LVL_W'(stg_n));

	always_ff @(posedge clk) begin
		if (!rstn) begin
			rd_sel_r <= ROWS'(1);
		end else if (load_fire) begin
			rd_sel_r <= rd_sel_r[ROWS-1] ? ROWS'(1) : (rd_sel_r << 1);
		end else begin
			rd_sel_r <= ROWS'(1) << rd_ptr;
		end
	end

	always_comb begin
		mem_rd = '0;
		for (int r = 0; r < ROWS; r++) begin
			if (rd_sel_r[r]) begin
				mem_rd = mem[r];
			end
		end
	end

	wire [ROW_W-1:0] stg_cur = rd_idx ? stg1_r : stg0_r;
	wire [R1_BITS-1:0] stg_nxt_lo = rd_idx ? stg0_r[R1_BITS-1:0] : stg1_r[R1_BITS-1:0];
	wire [WIN_W-1:0] win = {stg_nxt_lo, stg_cur};

	wire [(TILE_BEATS*BEAT_W)-1:0] beat_flat;
	wire [TILE_BEATS-1:0] str_lut, adv_lut;

	genvar i;
	generate
		for (i = 0; i < TILE_BEATS; i = i + 1) begin : gen_beat
			localparam integer OFF = (BEAT_W * i) % ROW_W;
			assign beat_flat[i*BEAT_W +: BEAT_W] = win[OFF +: BEAT_W];
			assign str_lut[i] = ((OFF + BEAT_W) > ROW_W);
			assign adv_lut[i] = (((BEAT_W * (i+1)) / ROW_W) > ((BEAT_W * i) / ROW_W));
		end
	endgenerate

	wire [BEAT_W-1:0] beat_data = beat_flat[beat_idx*BEAT_W +: BEAT_W];
	logic beat_str_r, beat_adv_r;
	wire [BI_W-1:0] beat_idx_nxt =
		(beat_idx == BI_W'(TILE_BEATS-1)) ? '0 : (beat_idx + 1'b1);

	wire beat_str = beat_str_r;
	wire beat_adv = beat_adv_r;

	logic [BEAT_W-1:0] head_r;
	logic head_valid_r;

	wire beat_ready = (stg_n != 2'd0) && (!beat_str || (stg_n == 2'd2));
	wire transfer = beat_ready && (!head_valid_r || rd_en);
	wire consume = head_valid_r && rd_en;
	wire row_retire = transfer && beat_adv;

	always_ff @(posedge clk) begin
		if (!rstn) begin
			wr_idx <= 1'b0;
			rd_idx <= 1'b0;
			stg_n  <= 2'd0;
			rd_ptr <= '0;
		end else begin
			if (load_fire) begin
				wr_idx <= ~wr_idx;
				rd_ptr <= (rd_ptr == PTR_W'(ROWS-1)) ? '0 : (rd_ptr + 1'b1);
			end
			if (row_retire) begin
				rd_idx <= ~rd_idx;
			end
			stg_n <= stg_n + {1'b0, load_fire} - {1'b0, row_retire};
		end
	end

	always_ff @(posedge clk) begin
		if (load_fire && !wr_idx) begin
			stg0_r <= mem_rd;
		end
	end

	always_ff @(posedge clk) begin
		if (load_fire && wr_idx) begin
			stg1_r <= mem_rd;
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			beat_idx   <= '0;
			beat_str_r <= str_lut[0];
			beat_adv_r <= adv_lut[0];
		end else if (transfer) begin
			beat_idx   <= beat_idx_nxt;
			beat_str_r <= str_lut[beat_idx_nxt];
			beat_adv_r <= adv_lut[beat_idx_nxt];
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
		end else begin
			level_r <= level_r + LVL_W'(push) - LVL_W'(row_retire);
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
			committed_r <= committed_r + (i_reserve ? CMT_W'(MATRIX_SIZE) : CMT_W'(0)) - CMT_W'(row_retire);
		end
	end

	assign o_rdata = head_r;
	assign o_valid = head_valid_r;
	assign o_room = ((committed_r + CMT_W'(MATRIX_SIZE)) <= CMT_W'(ROWS));
	assign o_level = level_r;
	assign o_overflow = overflow_r;

endmodule
`default_nettype wire
