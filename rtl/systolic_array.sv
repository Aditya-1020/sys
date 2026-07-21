`default_nettype wire
`timescale 1ps/1ps

module systolic_array #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	parameter integer RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 18 sum the products without overflow
	parameter integer TOTAL_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE, // 16
	parameter integer INPUT_PACKED_W =  TOTAL_ELEMENTS * DATA_WIDTH, // 16 * 8 = 128
	parameter integer LANE_W = $clog2(MATRIX_SIZE),
	parameter integer ROW_W = MATRIX_SIZE*DATA_WIDTH // 32
)(
	input wire clk,
	input wire rstn,
	input  wire i_start,
	input  wire i_a_valid,
	input  wire [ROW_W-1:0] i_ld_a, // one matrix a row per valid
	input wire i_b_en,
	input wire [LANE_W-1:0] i_b_lane,
	input wire [ROW_W-1:0] i_b_wdata,

	// results stream single element per valid,ready
	output wire [RESULT_WIDTH-1:0] o_result_data,
	output wire o_result_valid,
	input  wire i_result_ready,
	output wire o_done,
	output wire o_busy
);
	localparam integer ARRAY_ROWS = MATRIX_SIZE;
	localparam integer ARRAY_COLS = MATRIX_SIZE;
	localparam integer INNER_DIM = MATRIX_SIZE; // K MACs per column

	localparam integer FILL_CYCLES = (ARRAY_ROWS-1) + (ARRAY_COLS-1);
	localparam integer PE_LATENCY = 1;
	localparam integer FEED_LATENCY = 0; // a feeds combinationally; the pe registers it
	localparam integer TOTAL_COMPUTE_CYCLES = FILL_CYCLES + INNER_DIM + FEED_LATENCY + PE_LATENCY; 
	localparam integer COUNT_WIDTH = $clog2(TOTAL_COMPUTE_CYCLES + 1);
    
	typedef enum logic [1:0] {
		LOAD,  // idle cum receive a and b
		CLEAR,
		COMPUTE,
		STREAM // drain result to the output
	} state_t;
	state_t current_state, next_state;

	// current state never decoded combinationally (was killing my timing)
	logic [MATRIX_SIZE-1:0] en_col_r, clear_col_r;
	
	// gated
	(* keep *) logic en_feed_r; // feed a mux into col 0
	(* keep *) logic en_res_r; // result_buf capture
	logic state_load_r; // a_mat_r; drives busy/start
	logic stream_r;

	// compute phase counter
	logic [COUNT_WIDTH-1:0] cycle_count_r;
	wire compute_last = (current_state == COMPUTE) && (cycle_count_r == COUNT_WIDTH'(TOTAL_COMPUTE_CYCLES-1));
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			cycle_count_r <= '0;
		end else if (current_state != COMPUTE) begin
			cycle_count_r <= '0;
		end else begin
			cycle_count_r <= cycle_count_r + 1'b1;
		end
	end

	localparam integer IDX_W = $clog2(TOTAL_ELEMENTS);
	logic [IDX_W-1:0] rd_idx;
	wire beat = stream_r && i_result_ready;
	wire stream_last = beat && (rd_idx == IDX_W'(TOTAL_ELEMENTS-1));

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_idx <= '0;
		end else if (!stream_r) begin
			rd_idx <= '0;
		end else if (i_result_ready) begin
			rd_idx <= rd_idx + 1'b1;
		end
	end

	assign o_busy = !state_load_r;
	wire start_array = i_start && state_load_r;
	
	// next state logic
	always_comb begin
		next_state = current_state;
		unique case (current_state)
			LOAD: begin
				if (start_array) begin
					next_state = CLEAR;
				end
			end
			CLEAR: next_state = COMPUTE;
			COMPUTE: begin
				if (compute_last) begin
					next_state = STREAM;
				end
			end
			STREAM: begin
				if (stream_last) begin
					next_state = LOAD;
				end
			end
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
	wire clear_head_next = (next_state == CLEAR);
	wire stream_next = (next_state == STREAM);
	wire state_load_next = (next_state == LOAD);

	wire [MATRIX_SIZE-1:0] en_col_next = {en_col_r[MATRIX_SIZE-2:0], en_head_next};
	wire [MATRIX_SIZE-1:0] clear_col_next = {clear_col_r[MATRIX_SIZE-2:0], clear_head_next};

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			en_col_r <= '0;
			clear_col_r <= '0;
			en_feed_r <= 1'b0;
			en_res_r <= 1'b0;
			stream_r <= 1'b0;
			state_load_r <= 1'b1; // reset state is LOAD
		end else begin
			en_col_r <= en_col_next;
			clear_col_r <= clear_col_next;
			en_feed_r <= en_head_next;
			en_res_r <= en_head_next;
			stream_r <= stream_next;
			state_load_r <= state_load_next;
		end
	end
	
	// sticky done
	logic done_r, done_st;
	always_comb begin
		done_st = done_r;
		if (start_array) begin
			done_st = 1'b0; // clear on new job
		end else if (stream_last) begin
			done_st = 1'b1; // latch when the last result has been accepted
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			done_r <= 1'b0;
		end else begin
			done_r <= done_st;
		end
	end

	assign o_done = done_r;

	wire [ARRAY_ROWS-1:0] pe_w_load;
	genvar w;
	generate
		for (w = 0; w < ARRAY_ROWS; w = w + 1) begin : gen_weight_load
			assign pe_w_load[w] = i_b_en && (i_b_lane == w);
		end
	endgenerate

	wire [DATA_WIDTH-1:0] pe_a_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_a_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_w_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [RESULT_WIDTH-1:0] pe_psum_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [RESULT_WIDTH-1:0] pe_psum_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];

	genvar r, c;
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_pe_row
			for (c = 0; c < ARRAY_COLS; c = c+1 ) begin : gen_pe_column
				pe #(
					.DATA_WIDTH(DATA_WIDTH),
					.MATRIX_SIZE(MATRIX_SIZE),
					.ACC_WIDTH (RESULT_WIDTH)
				) u_pe (
					.clk     (clk),
					.i_enable(en_col_r[c]),
					.i_clear (clear_col_r[c]),
					.i_w_load(pe_w_load[r]),
					.i_a     (pe_a_in[r][c]),
					.i_b     (pe_w_in[r][c]),
					.i_psum  (pe_psum_in[r][c]),
					.o_a     (pe_a_out[r][c]),
					.o_psum  (pe_psum_out[r][c])
				);

				// stationary weight from b_r
				assign pe_w_in[r][c] = i_b_wdata[DATA_WIDTH*c +: DATA_WIDTH];

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

	// a streams one row per valid during idle
	logic [INPUT_PACKED_W-1:0] a_mat_r;
	always_ff @(posedge clk) begin
		if (i_a_valid && state_load_r) begin
			a_mat_r <= {i_ld_a, a_mat_r[INPUT_PACKED_W-1:ROW_W]};
		end
	end

	// feeding wires
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_a_feed
			wire [COUNT_WIDTH-1:0] elm_a = cycle_count_r - COUNT_WIDTH'(r);
			wire feed_window = en_feed_r && (elm_a < COUNT_WIDTH'(INNER_DIM));
			wire [COUNT_WIDTH-1:0] a_idx = feed_window ? elm_a : '0;
			assign pe_a_in[r][0] = feed_window ? a_mat_r[DATA_WIDTH*(INNER_DIM*a_idx + r) +: DATA_WIDTH] : '0;
		end
	endgenerate

	logic [RESULT_WIDTH-1:0] result_buf [0:TOTAL_ELEMENTS-1];
	always_ff @(posedge clk) begin
		if (en_res_r) begin
			for (int unsigned m = 0; m < ARRAY_ROWS; m++) begin
				for (int unsigned j = 0; j < ARRAY_COLS; j++) begin
					if (cycle_count_r == COUNT_WIDTH'(m + ARRAY_ROWS + j + FEED_LATENCY)) begin
						result_buf[m*ARRAY_COLS + j] <= pe_psum_out[ARRAY_ROWS-1][j];
					end
				end
			end
		end
	end

	// registered streaming
	logic [RESULT_WIDTH-1:0] c_data_r;
	wire [IDX_W-1:0] rd_next = rd_idx + 1'b1;
	wire stream_entry = stream_next && !stream_r;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			c_data_r <= '0;
		end else if (stream_entry) begin
			c_data_r <= result_buf[0];
		end else if (beat) begin
			c_data_r <= result_buf[rd_next];
		end
	end

	assign o_result_valid = stream_r;
	assign o_result_data  = c_data_r;

endmodule
`default_nettype none
