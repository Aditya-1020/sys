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
	input  wire i_start,
	input  wire i_a_valid,
	input  wire [ROW_W-1:0] i_ld_a, // one matrix a row per valid
	input wire i_b_en,
	input wire [LANE_W-1:0] i_b_lane,
	input wire [ROW_W-1:0] i_b_wdata,
	output wire [MATRIX_SIZE*RESULT_WIDTH-1:0] o_result_data, // one lane per column
	output wire [MATRIX_SIZE-1:0] o_result_valid,
	output wire o_done,
	output wire o_busy
);
	localparam integer ARRAY_ROWS = MATRIX_SIZE;
	localparam integer ARRAY_COLS = MATRIX_SIZE;
	localparam integer INNER_DIM = MATRIX_SIZE; // K MACs per column
	localparam integer PE_LATENCY = 3;
	localparam integer FEED_SKEW = 1; // k = feed skew + r + j
	localparam integer DRAIN_BASE = FEED_SKEW + ARRAY_ROWS + PE_LATENCY; // output
	localparam integer DRAIN_LAST = DRAIN_BASE + (ARRAY_COLS-1) + (ARRAY_ROWS-1);
	localparam integer TOTAL_COMPUTE_CYCLES = DRAIN_LAST + 1;
	localparam integer COUNT_WIDTH = $clog2(TOTAL_COMPUTE_CYCLES + 1);

	// results leave the columns as they are produced, no serialising drain
	typedef enum logic [1:0] {
		LOAD,  // idle cum receive a and b
		COMPUTE
	} state_t;
	state_t current_state, next_state;

	(* keep *) logic [ARRAY_ROWS-1:0] en_head_r;
	(* keep *) logic state_load_r;
	(* keep *) logic [MATRIX_SIZE-1:0] a_ld_sel_r; // a row shift reg en per row

	// compute phase counter
	logic [COUNT_WIDTH-1:0] cycle_count_r;
	wire [COUNT_WIDTH-1:0] cycle_count_next = (current_state == COMPUTE) ? (cycle_count_r + 1'b1) : '0;
	always_ff @(posedge clk) begin
		cycle_count_r <= cycle_count_next;
	end

	logic compute_last_r;

	assign o_busy = !state_load_r;
	wire start_array = i_start && (current_state == LOAD);
	// level sensity start hold high for conitnuous operations

	// next state logic
	always_comb begin
		next_state = current_state;
		case (current_state)
			LOAD: begin
				if (start_array) begin
					next_state = COMPUTE;
				end
			end
			COMPUTE: begin
				if (compute_last_r) begin
					next_state = LOAD;
				end
			end
			default: next_state = LOAD;
		endcase
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			current_state <= LOAD;
		end else begin
			current_state <= next_state;
		end
	end

	// registed state decode
	wire en_head_next = (next_state == COMPUTE);
	wire state_load_next = (next_state == LOAD);

	always_ff @(posedge clk) begin
		if (!rstn) begin
			en_head_r <= '0;
			compute_last_r <= 1'b0;
			state_load_r <= 1'b1; // reset state is LOAD
			a_ld_sel_r <= '1;
		end else begin
			compute_last_r <= en_head_r[0] && (cycle_count_r == COUNT_WIDTH'(TOTAL_COMPUTE_CYCLES-1));
			state_load_r <= state_load_next;
			en_head_r <= {ARRAY_ROWS{en_head_next}};
			a_ld_sel_r <= {MATRIX_SIZE{state_load_next || start_array}}; // load avail for extra cycle
		end
	end

	// sticky done
	logic done_r, done_st;
	always_comb begin
		done_st = done_r;
		if (start_array) begin
			done_st = 1'b0; // clear on new job
		end else if (compute_last_r) begin
			done_st = 1'b1;
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			done_r <= 1'b0;
		end else begin
			done_r <= done_st;
		end
	end

	assign o_done = done_r;

	logic b_en_r, a_valid_r;
	logic [LANE_W-1:0] b_lane_r;
	logic [ROW_W-1:0] b_wdata_r, load_a;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			b_en_r <= 1'b0;
			a_valid_r <= 1'b0;
		end else begin
			a_valid_r <= i_a_valid;
			b_en_r <= i_b_en;
		end
	end

	always_ff @(posedge clk) begin
		b_lane_r <= i_b_lane;
		b_wdata_r <= i_b_wdata;
		load_a <= i_ld_a;
	end

	wire [ARRAY_ROWS-1:0] pe_w_load;
	genvar w;
	generate
		for (w = 0; w < ARRAY_ROWS; w = w + 1) begin : gen_weight_load
			assign pe_w_load[w] = state_load_r ? (b_en_r && (b_lane_r == w)) : '0;
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

				// enable left to right
				if (c == 0) begin : gen_ctrl_head
					assign pe_en_in[r][0]  = en_head_r[r];
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

	// registered feed drains
	logic [ARRAY_ROWS-1:0] feed_window_r;
	logic [ARRAY_COLS-1:0] drain_window_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			feed_window_r  <= '0;
			drain_window_r <= '0;
		end else begin
			for (int i = 0; i < ARRAY_ROWS; i++) begin
				feed_window_r[i] <= en_head_r[i] && (cycle_count_r >= COUNT_WIDTH'(FEED_SKEW + i)) && (cycle_count_r < COUNT_WIDTH'(FEED_SKEW + i + INNER_DIM));
			end
			for (int i = 0; i < ARRAY_COLS; i++) begin
				drain_window_r[i] <= en_head_r[i] && (cycle_count_r >= COUNT_WIDTH'(DRAIN_BASE + i)) && (cycle_count_r < COUNT_WIDTH'(DRAIN_BASE + i + ARRAY_ROWS));
			end
		end
	end

	// shift reg per row
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_a_feed
			wire a_ld_en = a_valid_r && a_ld_sel_r[r];
			wire a_sh_en = a_ld_en || feed_window_r[r];
			wire [DATA_WIDTH-1:0] a_fill = a_ld_en ? load_a[DATA_WIDTH*r +: DATA_WIDTH] : {DATA_WIDTH{1'b0}};

			logic [ROW_W-1:0] a_row_r;
			always_ff @(posedge clk) begin
				if (a_sh_en) begin
					a_row_r <= {a_row_r[ROW_W-DATA_WIDTH-1:0], a_fill};
				end
			end

			assign pe_a_in[r][0] = feed_window_r[r] ? a_row_r[ROW_W-1 -: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
		end
	endgenerate

	generate
		for (c = 0; c < ARRAY_COLS; c = c + 1) begin : gen_drain
			assign o_result_valid[c] = drain_window_r[c];
			assign o_result_data[RESULT_WIDTH*c +: RESULT_WIDTH] = pe_psum_out[ARRAY_ROWS-1][c];
		end
	endgenerate

endmodule
`default_nettype wire
