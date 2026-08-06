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

	logic [ROW_W-1:0] mem [0:ROWS-1];
	logic [PTR_W-1:0] wr_ptr [0:MATRIX_SIZE-1];
	logic [RLVL_W-1:0] level_r;

	wire full = (level_r == RLVL_W'(ROWS));
	wire row_valid = i_result_valid[MATRIX_SIZE-1];
	wire push = row_valid && !full;

	genvar c;
	generate
		for (c = 0; c < MATRIX_SIZE; c = c + 1) begin : gen_col
			wire signed [RESULT_WIDTH-1:0] din = signed'(i_result_data[RESULT_WIDTH*c +: RESULT_WIDTH]);
			wire wr_en = i_result_valid[c] && !full;

			always_ff @(posedge clk or negedge rstn) begin
				if (!rstn) begin
					wr_ptr[c] <= '0;
				end else if (wr_en) begin
					wr_ptr[c] <= wr_ptr[c] + 1'b1;
				end
			end

			always_ff @(posedge clk) begin
				if (wr_en) begin
					mem[wr_ptr[c]][RESULT_WIDTH*c +: RESULT_WIDTH] <= din;
				end
			end
		end
	endgenerate

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

	wire can_load = (level_r > RLVL_W'(row_buf_valid_r));
	wire load_row = (!row_buf_valid_r || pop_row) && can_load;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			row_buf_valid_r <= 1'b0;
		end else begin
			if (load_row) begin
				row_buf_valid_r <= 1'b1;
			end else if (pop_row) begin
				row_buf_valid_r <= 1'b0;
			end
		end
	end

	logic [ROWS-1:0] rd_sel_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_sel_r <= {{(ROWS-1){1'b0}}, 1'b1};
		end else if (load_row) begin
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
		if (load_row) begin
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
