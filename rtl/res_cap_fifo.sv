`default_nettype none
`timescale 1ps/1ps

module res_cap_fifo #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	parameter integer JOBS = 2,

	localparam integer RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 18
	localparam integer TOTAL_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE, // 16
	localparam integer DEPTH = JOBS * TOTAL_ELEMENTS, // 32
	localparam integer LVL_W = $clog2(DEPTH + 1) // 6
)(
	input wire clk,
	input wire rstn,
	input wire i_result_valid,
	input wire signed [RESULT_WIDTH-1:0] i_result_data,
	output wire o_room, // room for complete result capture
	input wire rd_en,
	output wire signed [RESULT_WIDTH-1:0] o_rdata,
	output wire o_valid,
	output wire [LVL_W-1:0] o_level,
	output wire o_overflow
);
	localparam integer PTR_W = $clog2(DEPTH); // 5

	reg signed [RESULT_WIDTH-1:0] buffer [0:DEPTH-1];
	logic [PTR_W-1:0] wr_ptr, rd_ptr;
	logic [LVL_W-1:0] level_r;

	wire full = (level_r == LVL_W'(DEPTH));
	wire empty = (level_r == '0);

	wire write = i_result_valid && !full;
	wire read = rd_en && !empty;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			level_r <= '0;
		end else if (write && !read) begin
			level_r <= level_r + 1'b1;
		end else if (read && !write) begin
			level_r <= level_r - 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			wr_ptr <= '0;
		end else if (write) begin
			wr_ptr <= wr_ptr + 1'b1;
		end
	end

	always_ff @(posedge clk) begin
		if (write) begin
			buffer[wr_ptr] <= i_result_data;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_ptr <= '0;
		end else if (read) begin
			rd_ptr <= rd_ptr + 1'b1;
		end
	end

	logic overflow_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			overflow_r <= 1'b0;
		end else if (i_result_valid && full) begin
			overflow_r <= 1'b1;
		end
	end

	assign o_rdata = buffer[rd_ptr]; // combinational read ik ik.. bruh
	assign o_valid = !empty;
	assign o_level = level_r;
	assign o_overflow = overflow_r;

	assign o_room = (level_r <= LVL_W'(DEPTH - TOTAL_ELEMENTS));

endmodule
`default_nettype wire
