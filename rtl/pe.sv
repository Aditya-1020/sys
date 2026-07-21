`default_nettype none
`timescale 1ps/1ps

/*
- weights and activations are symmetric int8
- relu outputs are treated as signed non-negative
*/

module pe #(
	parameter integer DATA_WIDTH = 8,
	parameter integer MATRIX_SIZE = 4,
	parameter integer ACC_WIDTH = 2*DATA_WIDTH + $clog2(MATRIX_SIZE)
)(
	input wire clk,
	input wire i_enable, // compute
	input wire i_clear,// clear accumulator
	input wire i_w_load,
	input wire signed [DATA_WIDTH-1:0] i_a,
	input wire signed [DATA_WIDTH-1:0] i_b,
	input wire [ACC_WIDTH-1:0] i_psum,
	output wire [DATA_WIDTH-1:0] o_a,
	output wire [ACC_WIDTH-1:0] o_psum
);
	logic signed [DATA_WIDTH-1:0] a_r; // pass through only
	always_ff @(posedge clk) begin
		if (i_enable) begin
			a_r <= i_a;
		end
	end

	logic signed [DATA_WIDTH-1:0] w_r;
	always_ff @(posedge clk) begin
		if (i_w_load) begin
			w_r <= i_b;
		end
	end

	logic signed [2*DATA_WIDTH:0] mult_w;
	assign mult_w = a_r * w_r;

	logic signed [ACC_WIDTH-1:0] accumulator, next_acc;
	always_comb begin
		next_acc = signed'(i_psum) + ACC_WIDTH'(mult_w);
	end

	always_ff @(posedge clk) begin
		if (i_clear) begin
			accumulator <= '0;
		end else if (i_enable) begin
			accumulator <= next_acc;
		end
	end

	assign o_psum = accumulator;
	assign o_a = a_r;

endmodule
`default_nettype wire
