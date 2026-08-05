`default_nettype none
`timescale 1ps/1ps

module res_cap_fifo #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	localparam integer JOBS = 2,
	localparam integer RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 18
	localparam integer TOTAL_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE, // 16
	localparam integer DEPTH = JOBS * TOTAL_ELEMENTS, // 32
	localparam integer LVL_W = $clog2(DEPTH + 1) // 6
)(
	input wire clk,
	input wire rstn,
	input wire [MATRIX_SIZE-1:0] i_result_valid, // one per column
	input wire [MATRIX_SIZE*RESULT_WIDTH-1:0] i_result_data,
	output wire o_room,
	input wire rd_en,
	output wire signed [RESULT_WIDTH-1:0] o_rdata,
	output wire o_valid,
	output wire [LVL_W-1:0] o_level,
	output wire o_overflow
);
	localparam integer ROW_W = MATRIX_SIZE * RESULT_WIDTH; // 72
	localparam integer ROWS = JOBS * MATRIX_SIZE; // 8 for 2 jobs
	localparam integer PTR_W = $clog2(ROWS); // 3
	localparam integer RLVL_W = $clog2(ROWS + 1); // 4
	localparam integer COL_W = $clog2(MATRIX_SIZE); // 2

	// align cols to rows
	wire [ROW_W-1:0] row_data;
	wire [MATRIX_SIZE-1:0] row_valid_v;

	genvar c;
	generate
		for (c = 0; c < MATRIX_SIZE; c = c + 1) begin : gen_skew
			localparam integer DLY = MATRIX_SIZE - 1 - c;
			wire signed [RESULT_WIDTH-1:0] din = signed'(i_result_data[RESULT_WIDTH*c +: RESULT_WIDTH]);
		
			if (DLY == 0) begin : gen_passthru
				assign row_data[RESULT_WIDTH*c +: RESULT_WIDTH] = din;
				assign row_valid_v[c] = i_result_valid[c];
			end else begin : gen_delay
				logic signed [RESULT_WIDTH-1:0] d_sr [0:DLY-1];
				
				logic [DLY-1:0] v_sr;
				always_ff @(posedge clk) begin
					if (!rstn) begin
						v_sr <= '0;
					end else begin
						v_sr[0] <= i_result_valid[c];
						for (int k = 1; k < DLY; k++) begin
							v_sr[k] <= v_sr[k-1];
						end
					end
				end
			
				always_ff @(posedge clk) begin
					if (!rstn) begin
						for (int k = 0; k < DLY; k++) begin
							d_sr[k] <= '0;
						end
					end else begin
						d_sr[0] <= din;
						for (int k = 1; k < DLY; k++) begin
							d_sr[k] <= d_sr[k-1];
						end
					end
				end
			
				assign row_data[RESULT_WIDTH*c +: RESULT_WIDTH] = d_sr[DLY-1];
				assign row_valid_v[c] = v_sr[DLY-1];
			end
		end
	endgenerate

	wire row_valid = &row_valid_v;

	logic [ROW_W-1:0] mem [0:ROWS-1];
	logic [PTR_W-1:0] wr_ptr;
	logic [RLVL_W-1:0] level_r;

	wire full = (level_r == RLVL_W'(ROWS));
	wire empty = (level_r == '0);
	wire push = row_valid && !full;

	logic [ROW_W-1:0] row_buf_r;
	logic row_buf_valid_r;

	logic signed [RESULT_WIDTH-1:0] head_r;
	logic head_valid_r;
	logic [COL_W-1:0] rd_sub;

	wire consume = head_valid_r && rd_en;
	wire stage2_needs_data = !head_valid_r || consume;
	wire stage1_has_data = row_buf_valid_r;

	wire transfer = stage2_needs_data && stage1_has_data;
	wire last_element = (rd_sub == COL_W'(MATRIX_SIZE-1));
	wire pop_row = transfer && last_element;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			row_buf_valid_r <= 1'b0;
		end else begin
			if (transfer && last_element) begin
				row_buf_valid_r <= 1'b0;
			end else if (!row_buf_valid_r && !empty) begin
				row_buf_valid_r <= 1'b1;
			end
		end
	end

	logic [ROWS-1:0] rd_sel_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_sel_r <= {{(ROWS-1){1'b0}}, 1'b1};
		end else if (pop_row) begin
			rd_sel_r <= {rd_sel_r[ROWS-2:0], rd_sel_r[ROWS-1]};
		end
	end

	logic [ROW_W-1:0] mem_rd;
	always_comb begin
		mem_rd = '0;
		for (int r = 0; r < ROWS; r++) begin
			mem_rd |= {ROW_W{rd_sel_r[r]}} & mem[r];
		end
	end

	always_ff @(posedge clk) begin
		if (!row_buf_valid_r && !empty) begin
			row_buf_r <= mem_rd;
		end
	end

	// mux from row buffer
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			head_valid_r <= 1'b0;
			rd_sub <= '0;
		end else if (transfer) begin
			head_valid_r <= 1'b1;
			rd_sub <= last_element ? '0 : (rd_sub + 1'b1);
		end else if (consume) begin
			head_valid_r <= 1'b0;
		end
	end

	always_ff @(posedge clk) begin
		if (transfer) begin
			head_r <= signed'(row_buf_r[RESULT_WIDTH*rd_sub +: RESULT_WIDTH]);
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			wr_ptr <= '0;
		end else if (push) begin
			wr_ptr <= wr_ptr + 1'b1;
		end
	end

	always_ff @(posedge clk) begin
		if (push) begin
			mem[wr_ptr] <= row_data;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			level_r <= '0;
		end else if (push && !pop_row) begin
			level_r <= level_r + 1'b1;
		end else if (pop_row && !push) begin
			level_r <= level_r - 1'b1;
		end
	end

	logic overflow_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			overflow_r <= 1'b0;
		end else if (row_valid && full) begin
			overflow_r <= 1'b1;
		end
	end

	assign o_rdata = head_r;
	assign o_valid = head_valid_r;
	assign o_room = (level_r <= RLVL_W'(ROWS - MATRIX_SIZE)); // room for one more job
	assign o_level = LVL_W'({level_r, {COL_W{1'b0}}});
	assign o_overflow = overflow_r;

endmodule
`default_nettype wire
