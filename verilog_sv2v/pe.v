`timescale 1ps/1ps
`default_nettype none
module pe (
	clk,
	rstn,
	i_enable,
	i_w_load,
	i_a,
	i_b,
	i_psum,
	o_a,
	o_psum,
	o_enable
);
	parameter integer DATA_WIDTH = 8;
	parameter integer MATRIX_SIZE = 4;
	parameter integer ACC_WIDTH = (2 * DATA_WIDTH) + $clog2(MATRIX_SIZE);
	input wire clk;
	input wire rstn;
	input wire i_enable;
	input wire i_w_load;
	input wire signed [DATA_WIDTH - 1:0] i_a;
	input wire signed [DATA_WIDTH - 1:0] i_b;
	input wire signed [ACC_WIDTH - 1:0] i_psum;
	output wire signed [DATA_WIDTH - 1:0] o_a;
	output wire signed [ACC_WIDTH - 1:0] o_psum;
	output wire o_enable;
	reg signed [DATA_WIDTH - 1:0] a_r;
	always @(posedge clk)
		if (i_enable)
			a_r <= i_a;
	reg en_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			en_r <= 1'b0;
		else
			en_r <= i_enable;
	reg signed [DATA_WIDTH - 1:0] w_r;
	always @(posedge clk)
		if (i_w_load)
			w_r <= i_b;
	wire signed [(2 * DATA_WIDTH) - 1:0] mult_w;
	assign mult_w = a_r * w_r;
	reg signed [(2 * DATA_WIDTH) - 1:0] mult_r;
	always @(posedge clk)
		if (i_enable)
			mult_r <= mult_w;
	reg signed [ACC_WIDTH - 1:0] accumulator;
	wire signed [ACC_WIDTH - 1:0] next_acc;
	function automatic signed [ACC_WIDTH - 1:0] sv2v_cast_25A05_signed;
		input reg signed [ACC_WIDTH - 1:0] inp;
		sv2v_cast_25A05_signed = inp;
	endfunction
	assign next_acc = i_psum + sv2v_cast_25A05_signed(mult_r);
	always @(posedge clk)
		if (i_enable)
			accumulator <= next_acc;
	assign o_psum = accumulator;
	assign o_a = a_r;
	assign o_enable = en_r;
endmodule
`default_nettype wire
