`timescale 1ps/1ps
`default_nettype none
module systolic_array (
	clk,
	rstn,
	i_start,
	i_a_valid,
	i_ld_a,
	i_b_en,
	i_b_lane,
	i_b_wdata,
	o_result_data,
	o_result_valid,
	o_done,
	o_busy
);
	reg _sv2v_0;
	parameter integer MATRIX_SIZE = 4;
	parameter integer DATA_WIDTH = 8;
	localparam integer RESULT_WIDTH = (2 * DATA_WIDTH) + $clog2(MATRIX_SIZE);
	localparam integer LANE_W = $clog2(MATRIX_SIZE);
	localparam integer ROW_W = MATRIX_SIZE * DATA_WIDTH;
	input wire clk;
	input wire rstn;
	input wire i_start;
	input wire i_a_valid;
	input wire [ROW_W - 1:0] i_ld_a;
	input wire i_b_en;
	input wire [LANE_W - 1:0] i_b_lane;
	input wire [ROW_W - 1:0] i_b_wdata;
	output wire [(MATRIX_SIZE * RESULT_WIDTH) - 1:0] o_result_data;
	output wire [MATRIX_SIZE - 1:0] o_result_valid;
	output wire o_done;
	output wire o_busy;
	localparam integer ARRAY_ROWS = MATRIX_SIZE;
	localparam integer ARRAY_COLS = MATRIX_SIZE;
	localparam integer INNER_DIM = MATRIX_SIZE;
	localparam integer PE_LATENCY = 2;
	localparam integer FEED_SKEW = 1;
	localparam integer DRAIN_BASE = (FEED_SKEW + ARRAY_ROWS) + PE_LATENCY;
	localparam integer DRAIN_LAST = (DRAIN_BASE + (ARRAY_COLS - 1)) + (ARRAY_ROWS - 1);
	localparam integer TOTAL_COMPUTE_CYCLES = DRAIN_LAST + 1;
	localparam integer COUNT_WIDTH = $clog2(TOTAL_COMPUTE_CYCLES + 1);
	reg [1:0] current_state;
	reg [1:0] next_state;
	(* keep *) reg [ARRAY_ROWS - 1:0] en_head_r;
	(* keep *) reg state_load_r;
	(* keep *) reg [MATRIX_SIZE - 1:0] a_ld_sel_r;
	reg [COUNT_WIDTH - 1:0] cycle_count_r;
	wire [COUNT_WIDTH - 1:0] cycle_count_next = (current_state == 2'd1 ? cycle_count_r + 1'b1 : {COUNT_WIDTH {1'sb0}});
	always @(posedge clk) cycle_count_r <= cycle_count_next;
	reg compute_last_r;
	assign o_busy = !state_load_r;
	wire start_array = i_start && (current_state == 2'd0);
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = current_state;
		case (current_state)
			2'd0:
				if (start_array)
					next_state = 2'd1;
			2'd1:
				if (compute_last_r)
					next_state = 2'd0;
			default: next_state = 2'd0;
		endcase
	end
	always @(posedge clk or negedge rstn)
		if (!rstn)
			current_state <= 2'd0;
		else
			current_state <= next_state;
	wire en_head_next = next_state == 2'd1;
	wire state_load_next = next_state == 2'd0;
	function automatic signed [COUNT_WIDTH - 1:0] sv2v_cast_5A7F5_signed;
		input reg signed [COUNT_WIDTH - 1:0] inp;
		sv2v_cast_5A7F5_signed = inp;
	endfunction
	always @(posedge clk)
		if (!rstn) begin
			en_head_r <= 1'sb0;
			compute_last_r <= 1'b0;
			state_load_r <= 1'b1;
			a_ld_sel_r <= 1'sb1;
		end
		else begin
			compute_last_r <= en_head_r[0] && (cycle_count_r == sv2v_cast_5A7F5_signed(TOTAL_COMPUTE_CYCLES - 1));
			state_load_r <= state_load_next;
			en_head_r <= {ARRAY_ROWS {en_head_next}};
			a_ld_sel_r <= {MATRIX_SIZE {state_load_next || start_array}};
		end
	reg done_r;
	reg done_st;
	always @(*) begin
		if (_sv2v_0)
			;
		done_st = done_r;
		if (start_array)
			done_st = 1'b0;
		else if (compute_last_r)
			done_st = 1'b1;
	end
	always @(posedge clk)
		if (!rstn)
			done_r <= 1'b0;
		else
			done_r <= done_st;
	assign o_done = done_r;
	reg b_en_r;
	reg a_valid_r;
	reg [LANE_W - 1:0] b_lane_r;
	reg [ROW_W - 1:0] b_wdata_r;
	reg [ROW_W - 1:0] load_a;
	always @(posedge clk or negedge rstn)
		if (!rstn) begin
			b_en_r <= 1'b0;
			a_valid_r <= 1'b0;
		end
		else begin
			a_valid_r <= i_a_valid;
			b_en_r <= i_b_en;
			b_lane_r <= i_b_lane;
			b_wdata_r <= i_b_wdata;
			load_a <= i_ld_a;
		end
	wire [ARRAY_ROWS - 1:0] pe_w_load;
	genvar _gv_w_1;
	generate
		for (_gv_w_1 = 0; _gv_w_1 < ARRAY_ROWS; _gv_w_1 = _gv_w_1 + 1) begin : gen_weight_load
			localparam w = _gv_w_1;
			assign pe_w_load[w] = (state_load_r ? b_en_r && (b_lane_r == w) : 1'b0);
		end
	endgenerate
	wire [DATA_WIDTH - 1:0] pe_a_in [0:ARRAY_ROWS - 1][0:ARRAY_COLS - 1];
	wire [DATA_WIDTH - 1:0] pe_a_out [0:ARRAY_ROWS - 1][0:ARRAY_COLS - 1];
	wire [DATA_WIDTH - 1:0] pe_w_in [0:ARRAY_ROWS - 1][0:ARRAY_COLS - 1];
	wire signed [RESULT_WIDTH - 1:0] pe_psum_in [0:ARRAY_ROWS - 1][0:ARRAY_COLS - 1];
	wire signed [RESULT_WIDTH - 1:0] pe_psum_out [0:ARRAY_ROWS - 1][0:ARRAY_COLS - 1];
	wire pe_en_in [0:ARRAY_ROWS - 1][0:ARRAY_COLS - 1];
	wire pe_en_out [0:ARRAY_ROWS - 1][0:ARRAY_COLS - 1];
	genvar _gv_r_1;
	genvar _gv_c_1;
	generate
		for (_gv_r_1 = 0; _gv_r_1 < ARRAY_ROWS; _gv_r_1 = _gv_r_1 + 1) begin : gen_pe_row
			localparam r = _gv_r_1;
			for (_gv_c_1 = 0; _gv_c_1 < ARRAY_COLS; _gv_c_1 = _gv_c_1 + 1) begin : gen_pe_col
				localparam c = _gv_c_1;
				pe #(
					.DATA_WIDTH(DATA_WIDTH),
					.MATRIX_SIZE(MATRIX_SIZE),
					.ACC_WIDTH(RESULT_WIDTH)
				) u_pe(
					.clk(clk),
					.rstn(rstn),
					.i_enable(pe_en_in[r][c]),
					.i_w_load(pe_w_load[r]),
					.i_a(pe_a_in[r][c]),
					.i_b(pe_w_in[r][c]),
					.i_psum(pe_psum_in[r][c]),
					.o_a(pe_a_out[r][c]),
					.o_psum(pe_psum_out[r][c]),
					.o_enable(pe_en_out[r][c])
				);
				if (c == 0) begin : gen_ctrl_head
					assign pe_en_in[r][0] = en_head_r[r];
				end
				else begin : gen_ctrl_flow
					assign pe_en_in[r][c] = pe_en_out[r][c - 1];
				end
				assign pe_w_in[r][c] = b_wdata_r[DATA_WIDTH * c+:DATA_WIDTH];
				if (c < (ARRAY_COLS - 1)) begin : gen_a_flow
					assign pe_a_in[r][c + 1] = pe_a_out[r][c];
				end
				if (r == 0) begin : gen_psum_head
					assign pe_psum_in[r][c] = 1'sb0;
				end
				else begin : gen_psum_flow
					assign pe_psum_in[r][c] = pe_psum_out[r - 1][c];
				end
			end
		end
	endgenerate
	reg [ARRAY_ROWS - 1:0] feed_window_r;
	reg [ARRAY_COLS - 1:0] drain_window_r;
	always @(posedge clk or negedge rstn)
		if (!rstn) begin
			feed_window_r <= 1'sb0;
			drain_window_r <= 1'sb0;
		end
		else begin
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < ARRAY_ROWS; i = i + 1)
					feed_window_r[i] <= (en_head_r[i] && (cycle_count_r >= sv2v_cast_5A7F5_signed(FEED_SKEW + i))) && (cycle_count_r < sv2v_cast_5A7F5_signed((FEED_SKEW + i) + INNER_DIM));
			end
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < ARRAY_COLS; i = i + 1)
					drain_window_r[i] <= (en_head_r[i] && (cycle_count_r >= sv2v_cast_5A7F5_signed(DRAIN_BASE + i))) && (cycle_count_r < sv2v_cast_5A7F5_signed((DRAIN_BASE + i) + ARRAY_ROWS));
			end
		end
	generate
		for (_gv_r_1 = 0; _gv_r_1 < ARRAY_ROWS; _gv_r_1 = _gv_r_1 + 1) begin : gen_a_feed
			localparam r = _gv_r_1;
			wire a_ld_en = a_valid_r && a_ld_sel_r[r];
			wire a_sh_en = a_ld_en || feed_window_r[r];
			wire [DATA_WIDTH - 1:0] a_fill = (a_ld_en ? load_a[DATA_WIDTH * r+:DATA_WIDTH] : {DATA_WIDTH {1'b0}});
			reg [ROW_W - 1:0] a_row_r;
			always @(posedge clk)
				if (a_sh_en)
					a_row_r <= {a_row_r[(ROW_W - DATA_WIDTH) - 1:0], a_fill};
			assign pe_a_in[r][0] = (feed_window_r[r] ? a_row_r[ROW_W - 1-:DATA_WIDTH] : {DATA_WIDTH {1'b0}});
		end
		for (_gv_c_1 = 0; _gv_c_1 < ARRAY_COLS; _gv_c_1 = _gv_c_1 + 1) begin : gen_drain
			localparam c = _gv_c_1;
			assign o_result_valid[c] = drain_window_r[c];
			assign o_result_data[RESULT_WIDTH * c+:RESULT_WIDTH] = pe_psum_out[ARRAY_ROWS - 1][c];
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
