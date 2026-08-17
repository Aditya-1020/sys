`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,

	localparam integer RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 18 sum the products without overflow
	localparam integer LANE_W = $clog2(MATRIX_SIZE),
	localparam integer ROW_W = MATRIX_SIZE*DATA_WIDTH // 32
)(
	input wire clk,
	input wire rstn,
	input  wire i_a_valid,
	input  wire [ROW_W-1:0] i_ld_a, // one matrix a row per valid
	input wire i_b_en,
	input wire [LANE_W-1:0] i_b_lane,
	input wire [ROW_W-1:0] i_b_wdata,
	output wire [MATRIX_SIZE*RESULT_WIDTH-1:0] o_result_data, // one lane per column
	output wire [MATRIX_SIZE-1:0] o_result_valid,
	output wire o_done, // one pulse per completed tile
	output wire o_busy
);
	localparam integer ARRAY_ROWS = MATRIX_SIZE;
	localparam integer ARRAY_COLS = MATRIX_SIZE;
	localparam integer PE_LATENCY = 4;
	localparam integer RESOLVE_LAT = 2; // carry-save -> binary resolve, split across 2 cycles (see gen_resolve)
	localparam integer DRAIN_LAT = ARRAY_ROWS + PE_LATENCY + RESOLVE_LAT; // 8
	localparam integer PIPE_DEPTH = DRAIN_LAT + ARRAY_COLS - 1; // 11

	logic [ROW_W-1:0] b_wdata_r, load_a;

	// dp
	always_ff @(posedge clk) begin
		b_wdata_r <= i_b_wdata;
		load_a <= i_ld_a;
	end

	// valid delay line
	logic [PIPE_DEPTH:0] vld_r;
	always_ff @(posedge clk) begin
		if (!rstn) begin
			vld_r <= '0;
		end else begin
			vld_r <= {vld_r[PIPE_DEPTH-1:0], i_a_valid};
		end
	end

	// anything in flight anywhere in the array
	wire array_active_next = |vld_r[PIPE_DEPTH-1:0] || i_a_valid;

	logic array_active_r;
	always_ff @(posedge clk) begin
		if (!rstn) begin
			array_active_r <= 1'b0;
		end else begin
			array_active_r <= array_active_next;
		end
	end

	assign o_busy = array_active_r;

	logic [LANE_W-1:0] row_cnt_r;
	wire a_last = i_a_valid && (row_cnt_r == LANE_W'(MATRIX_SIZE-1));

	always_ff @(posedge clk) begin
		if (!rstn) begin
			row_cnt_r <= '0;
		end else if (i_a_valid) begin
			row_cnt_r <= a_last ? '0 : (row_cnt_r + 1'b1);
		end
	end

	logic [PIPE_DEPTH:0] eot_r;
	always_ff @(posedge clk) begin
		if (!rstn) begin
			eot_r <= '0;
		end else begin
			eot_r <= {eot_r[PIPE_DEPTH-1:0], a_last};
		end
	end
	assign o_done = eot_r[PIPE_DEPTH];

	// input skew
	logic [ROW_W-1:0] a_dly [0:ARRAY_ROWS-1];
	always_comb begin
		a_dly[0] = load_a;
	end
	genvar d;
	generate
		for (d = 1; d < ARRAY_ROWS; d = d + 1) begin : gen_a_skew
			logic [ROW_W-1:0] stage_r;
			always_ff @(posedge clk) begin
				stage_r <= a_dly[d-1];
			end
			always_comb begin
				a_dly[d] = stage_r;
			end
		end
	endgenerate

	// stationary weights; reload when empty
	logic [ARRAY_ROWS-1:0] pe_w_load_r;
	genvar w;
	generate
		for (w = 0; w < ARRAY_ROWS; w = w + 1) begin : gen_weight_load
			always_ff @(posedge clk) begin
				if (!rstn) begin
					pe_w_load_r[w] <= 1'b0;
				end else begin
					pe_w_load_r[w] <= !array_active_next && i_b_en && (i_b_lane == LANE_W'(w));
				end
			end
		end
	endgenerate

	wire [DATA_WIDTH-1:0] pe_a_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_a_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_w_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire pe_en_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire pe_en_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	
	// carry-save psum pair
	wire signed [RESULT_WIDTH-1:0] pe_psum_s_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire signed [RESULT_WIDTH-1:0] pe_psum_c_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire signed [RESULT_WIDTH-1:0] pe_psum_s_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire signed [RESULT_WIDTH-1:0] pe_psum_c_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];

	wire pe_en_col0 = array_active_r;

	genvar r, c;
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_pe_row
			for (c = 0; c < ARRAY_COLS; c = c+1 ) begin : gen_pe_col
				pe #(
					.DATA_WIDTH(DATA_WIDTH),
					.MATRIX_SIZE(MATRIX_SIZE),
					.ACC_WIDTH (RESULT_WIDTH)
				) u_pe (
					.clk      (clk),
					.rstn     (rstn),
					.i_enable (pe_en_in[r][c]),
					.i_w_load (pe_w_load_r[r]),
					.i_a      (pe_a_in[r][c]),
					.i_b      (pe_w_in[r][c]),
					.i_psum_s (pe_psum_s_in[r][c]),
					.i_psum_c (pe_psum_c_in[r][c]),
					.o_a      (pe_a_out[r][c]),
					.o_psum_s (pe_psum_s_out[r][c]),
					.o_psum_c (pe_psum_c_out[r][c]),
					.o_enable (pe_en_out[r][c])
				);

				if (c == 0) begin : gen_ctrl_head
					assign pe_en_in[r][0] = pe_en_col0;
				end else begin : gen_ctrl_flow
					assign pe_en_in[r][c]  = pe_en_out[r][c-1];
				end

				// stationary weight from registerd ldb
				assign pe_w_in[r][c] = b_wdata_r[DATA_WIDTH*c +: DATA_WIDTH];

				// a to right b to bottom
				if (c < ARRAY_COLS-1) begin : gen_a_flow
					assign pe_a_in[r][c+1] = pe_a_out[r][c];
				end

				if (r == 0) begin : gen_psum_head
					assign pe_psum_s_in[r][c] = '0;
					assign pe_psum_c_in[r][c] = '0;
				end else begin : gen_psum_flow
					assign pe_psum_s_in[r][c] = pe_psum_s_out[r-1][c];
					assign pe_psum_c_in[r][c] = pe_psum_c_out[r-1][c];
				end
			end
		end
	endgenerate

	// feed row r
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_a_feed
			assign pe_a_in[r][0] = vld_r[r] ? a_dly[r][DATA_WIDTH*r +: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
		end
	endgenerate

	localparam integer RESOLVE_LOW_W = RESULT_WIDTH / 2;
	localparam integer RESOLVE_HIGH_W = RESULT_WIDTH - RESOLVE_LOW_W;

	logic [RESOLVE_LOW_W-1:0] resolve_low_sum_r [0:ARRAY_COLS-1];
	logic resolve_carry_r [0:ARRAY_COLS-1];
	logic [RESOLVE_HIGH_W-1:0] resolve_high_s_r [0:ARRAY_COLS-1];
	logic [RESOLVE_HIGH_W-1:0] resolve_high_c_r [0:ARRAY_COLS-1];
	logic signed [RESULT_WIDTH-1:0] resolved_r [0:ARRAY_COLS-1];
	
	generate
		for (c = 0; c < ARRAY_COLS; c = c + 1) begin : gen_resolve
			wire [RESOLVE_LOW_W-1:0] psum_s_low = pe_psum_s_out[ARRAY_ROWS-1][c][RESOLVE_LOW_W-1:0];
			wire [RESOLVE_LOW_W-1:0] psum_c_low = pe_psum_c_out[ARRAY_ROWS-1][c][RESOLVE_LOW_W-1:0];
			wire [RESULT_WIDTH-RESOLVE_LOW_W-1:0] psum_s_high = pe_psum_s_out[ARRAY_ROWS-1][c][RESULT_WIDTH-1:RESOLVE_LOW_W];
			wire [RESULT_WIDTH-RESOLVE_LOW_W-1:0] psum_c_high = pe_psum_c_out[ARRAY_ROWS-1][c][RESULT_WIDTH-1:RESOLVE_LOW_W];
			wire [RESOLVE_LOW_W:0] low_add = {1'b0, psum_s_low} + {1'b0, psum_c_low};
			
			always_ff @(posedge clk) begin
				resolve_low_sum_r[c] <= low_add[RESOLVE_LOW_W-1:0];
				resolve_carry_r[c] <= low_add[RESOLVE_LOW_W];
				resolve_high_s_r[c] <= psum_s_high;
				resolve_high_c_r[c] <= psum_c_high;
			end

			always_ff @(posedge clk) begin
				resolved_r[c] <= {resolve_high_s_r[c] + resolve_high_c_r[c] + RESOLVE_HIGH_W'(resolve_carry_r[c]), resolve_low_sum_r[c]};
			end
		end
	endgenerate

	// feed col c
	generate
		for (c = 0; c < ARRAY_COLS; c = c + 1) begin : gen_drain
			assign o_result_valid[c] = vld_r[DRAIN_LAT + c];
			assign o_result_data[RESULT_WIDTH*c +: RESULT_WIDTH] = unsigned'(resolved_r[c]);
		end
	endgenerate

endmodule
`default_nettype wire
