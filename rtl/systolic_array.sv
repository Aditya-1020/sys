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
	localparam integer PE_LATENCY = 2; // a_r -> mult_pipe -> accumulator
	localparam integer DRAIN_LAT = ARRAY_ROWS + PE_LATENCY; // 6
	localparam integer PIPE_DEPTH = DRAIN_LAT + ARRAY_COLS - 1; // 9

	logic b_en_r;
	logic [LANE_W-1:0] b_lane_r;
	logic [ROW_W-1:0] b_wdata_r, load_a;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			b_en_r <= 1'b0;
		end else begin
			b_en_r <= i_b_en;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			b_lane_r  <= '0;
			b_wdata_r <= '0;
			load_a    <= '0;
		end else begin
			b_lane_r  <= i_b_lane;
			b_wdata_r <= i_b_wdata;
			load_a    <= i_ld_a;
		end
	end

	// valid delay line
	logic [PIPE_DEPTH:0] vld_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			vld_r <= '0;
		end else begin
			vld_r <= {vld_r[PIPE_DEPTH-1:0], i_a_valid};
		end
	end

	// anything in flight anywhere in the array
	wire array_active = |vld_r;
	assign o_busy = array_active;

	logic [LANE_W-1:0] row_cnt_r;
	wire a_last = i_a_valid && (row_cnt_r == LANE_W'(MATRIX_SIZE-1));

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			row_cnt_r <= '0;
		end else if (i_a_valid) begin
			row_cnt_r <= a_last ? '0 : (row_cnt_r + 1'b1);
		end
	end

	logic [PIPE_DEPTH:0] eot_r;
	always_ff @(posedge clk or negedge rstn) begin
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
			always_ff @(posedge clk or negedge rstn) begin
				if (!rstn) begin
					stage_r <= '0;
				end else begin
					stage_r <= a_dly[d-1];
				end
			end
			always_comb begin
				a_dly[d] = stage_r;
			end
		end
	endgenerate

	// stationary weights; reload when empty
	wire [ARRAY_ROWS-1:0] pe_w_load;
	genvar w;
	generate
		for (w = 0; w < ARRAY_ROWS; w = w + 1) begin : gen_weight_load
			assign pe_w_load[w] = !array_active && b_en_r && (b_lane_r == LANE_W'(w));
		end
	endgenerate

	wire [DATA_WIDTH-1:0] pe_a_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_a_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_w_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire signed [RESULT_WIDTH-1:0] pe_psum_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire signed [RESULT_WIDTH-1:0] pe_psum_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire pe_en_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire pe_en_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];

	genvar r, c;
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_pe_row
			for (c = 0; c < ARRAY_COLS; c = c+1 ) begin : gen_pe_col
				pe #(
					.DATA_WIDTH(DATA_WIDTH),
					.MATRIX_SIZE(MATRIX_SIZE),
					.ACC_WIDTH (RESULT_WIDTH)
				) u_pe (
					.clk     (clk),
					.rstn    (rstn),
					.i_enable(pe_en_in[r][c]),
					.i_w_load(pe_w_load[r]),
					.i_a     (pe_a_in[r][c]),
					.i_b     (pe_w_in[r][c]),
					.i_psum  (pe_psum_in[r][c]),
					.o_a     (pe_a_out[r][c]),
					.o_psum  (pe_psum_out[r][c]),
					.o_enable(pe_en_out[r][c])
				);

				if (c == 0) begin : gen_ctrl_head
					assign pe_en_in[r][0]  = array_active;
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
					assign pe_psum_in[r][c] = '0;
				end else begin : gen_psum_flow
					assign pe_psum_in[r][c] = pe_psum_out[r-1][c];
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

	// feed col c
	generate
		for (c = 0; c < ARRAY_COLS; c = c + 1) begin : gen_drain
			assign o_result_valid[c] = vld_r[DRAIN_LAT + c];
			assign o_result_data[RESULT_WIDTH*c +: RESULT_WIDTH] = unsigned'(pe_psum_out[ARRAY_ROWS-1][c]);
		end
	endgenerate

endmodule
`default_nettype wire
