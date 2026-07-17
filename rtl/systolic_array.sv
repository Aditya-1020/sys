`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	parameter integer RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 19 sum the products without overflow
	parameter integer TOTAL_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE, // 16
	parameter integer INPUT_PACKED_W =  TOTAL_ELEMENTS * DATA_WIDTH, // 16 * 8 = 128
	parameter integer RESULT_PACKED_W = TOTAL_ELEMENTS * RESULT_WIDTH // 288
)(
	input wire clk,
	input wire rstn,
	input  wire i_start,
	input  wire [INPUT_PACKED_W-1:0] i_ld_a,
	input  wire [INPUT_PACKED_W-1:0] i_ld_b,
	input  wire i_pe_sign_en, // csr controlled
	// output wire [(MATRIX_SIZE*MATRIX_SIZE)-1:0][RESULT_WIDTH-1:0] o_result_data, /// --- CHANGGE THIS AND HANDLE IT FLAT BELOW
	output wire [RESULT_PACKED_W-1:0] o_result_data,
	output wire o_done,
	output wire o_busy
);
	localparam integer ARRAY_ROWS = MATRIX_SIZE;
	localparam integer ARRAY_COLS = MATRIX_SIZE;
	localparam integer INNER_DIM = MATRIX_SIZE; // K MACs per column

	localparam integer FILL_CYCLES = (ARRAY_ROWS-1) + (ARRAY_COLS-1);
	localparam integer PE_LATENCY = 1;
	localparam integer FEED_LATENCY = 1; // --
	localparam integer TOTAL_COMPUTE_CYCLES = FILL_CYCLES + INNER_DIM + FEED_LATENCY + PE_LATENCY; 
	localparam integer COUNT_WIDTH = $clog2(TOTAL_COMPUTE_CYCLES + 1);
    
	typedef enum logic [1:0] {
		LOAD,  // idle cum receive a and b
		CLEAR,
		COMPUTE
	} state_t;
	state_t current_state, next_state;

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

	// next state logic
	always_comb begin
		next_state = current_state;
		case (current_state)
			LOAD: begin
				if (i_start) begin
					next_state = CLEAR;
				end
			end
			CLEAR: next_state = COMPUTE;
			COMPUTE: begin
				if (compute_last) begin
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

	// sticky done
	logic done_r, done_st;
	always_comb begin
		done_st = done_r;
		if ((current_state == LOAD) && i_start) begin
			done_st = 1'b0; // clear on new job
		end else if (compute_last) begin
			done_st = 1'b1; // latch
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
	assign o_busy = (current_state != LOAD);

	wire pe_clear = (current_state == CLEAR);
	wire pe_enable = (current_state == COMPUTE);
	wire pe_w_load = (current_state == CLEAR);

	wire [DATA_WIDTH-1:0] pe_a_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_a_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [DATA_WIDTH-1:0] pe_w_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [RESULT_WIDTH-1:0] pe_psum_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	wire [RESULT_WIDTH-1:0] pe_psum_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];

	// col c control delayed by c
	wire [MATRIX_SIZE-1:0] pe_en_col, pe_clr_col;
	logic [MATRIX_SIZE-1:1] en_pipe_q, clr_pipe_q;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			en_pipe_q <= '0;
			clr_pipe_q <= '0;
		end else begin
			en_pipe_q <= pe_en_col[MATRIX_SIZE-2:0];
			clr_pipe_q <= pe_clr_col[MATRIX_SIZE-2:0];
		end
	end

	assign pe_en_col = {en_pipe_q, pe_enable};
	assign pe_clr_col = {clr_pipe_q, pe_clear};

	genvar r, c;
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_pe_row
			for (c = 0; c < ARRAY_COLS; c = c+1 ) begin : gen_pe_column
				pe #(
					.DATA_WIDTH(DATA_WIDTH),
					.ACC_WIDTH (RESULT_WIDTH)
				) u_pe (
					.clk     (clk),
					// .rstn    (rstn),
					.i_enable(pe_en_col[c]),
					.i_clear (pe_clr_col[c]),
					.i_signed(i_pe_sign_en),
					.i_w_load(pe_w_load),
					.i_a     (pe_a_in[r][c]),
					.i_b     (pe_w_in[r][c]),
					.i_psum  (pe_psum_in[r][c]),
					.o_a     (pe_a_out[r][c]),
					.o_psum  (pe_psum_out[r][c])
				);

				// stationary weight from b_r
				assign pe_w_in[r][c] = i_ld_b[DATA_WIDTH*(ARRAY_COLS*r + c) +: DATA_WIDTH];

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

	// feeding wires
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_a_feed
			wire [COUNT_WIDTH-1:0] elm_a = cycle_count_r - COUNT_WIDTH'(r);
			wire feed_window = (elm_a < COUNT_WIDTH'(INNER_DIM));
			wire [COUNT_WIDTH-1:0] a_idx = feed_window ? elm_a : '0;
			logic [DATA_WIDTH-1:0] pe_a_in_r;
			always_ff @(posedge clk) begin
				if (pe_enable && feed_window) begin
					pe_a_in_r <= i_ld_a[DATA_WIDTH*(INNER_DIM*a_idx + r)+: DATA_WIDTH];
				end else begin
					pe_a_in_r <= '0;
				end
			end
			assign pe_a_in[r][0] = pe_a_in_r;
		end
	endgenerate

	logic [RESULT_WIDTH-1:0] result_r [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
	// c[m][j] is valid on the drain for one cycle (m+N+j); latched to presetn in parallel
	always_ff @(posedge clk) begin
		if (pe_enable) begin
			for (int unsigned m = 0; m < ARRAY_ROWS; m++) begin
				for (int unsigned j = 0; j < ARRAY_COLS; j++) begin
					if (cycle_count_r == COUNT_WIDTH'(m + ARRAY_ROWS + j + FEED_LATENCY)) begin
						result_r[m][j] <= pe_psum_out[ARRAY_ROWS-1][j];
					end
				end
			end
		end
	end
    
	generate
		for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_result_row
			for (c = 0; c < ARRAY_COLS; c = c + 1) begin : gen_result_col
				// assign o_result_data[r*ARRAY_COLS + c] = result_r[r][c];
				assign o_result_data[RESULT_WIDTH*(r*ARRAY_COLS + c) +: RESULT_WIDTH] = result_r[r][c];
			end
		end
	endgenerate

endmodule
`default_nettype wire
