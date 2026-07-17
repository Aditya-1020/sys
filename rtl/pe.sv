`default_nettype none
`timescale 1ps/1ps

module pe #(
	parameter DATA_WIDTH = 8,
	parameter ACC_WIDTH = 16
)(
	input wire clk,
	input wire rstn,
	input wire i_enable, // compute
	input wire i_clear,// clear accumulator
	input wire i_signed,
	input wire i_w_load,
	input wire [DATA_WIDTH-1:0] i_a,
	input wire [DATA_WIDTH-1:0] i_b,
	input wire [ACC_WIDTH-1:0] i_psum,
	output wire [DATA_WIDTH-1:0] o_a,
	output wire [ACC_WIDTH-1:0] o_psum
);
	logic [DATA_WIDTH-1:0] a_r;
	always_ff @(posedge clk) begin
		if (i_enable) begin
			a_r <= i_a;
		end
	end

	logic [DATA_WIDTH-1:0] w_r;
	always_ff @(posedge clk) begin
		if (i_w_load) begin
			w_r <= i_b;
		end
	end

	wire a_s_bit, w_s_bit;
	assign a_s_bit = i_signed ? i_a[DATA_WIDTH-1] : 1'b0;
	assign w_s_bit = i_signed ? w_r[DATA_WIDTH-1] : 1'b0;

	logic signed [DATA_WIDTH:0] a_extend, w_extend;
	assign a_extend = {a_s_bit, i_a};
	assign w_extend = {w_s_bit, w_r};

	logic signed [2*DATA_WIDTH+1:0] mult_r;
	assign mult_r = a_extend * w_extend;

	logic signed [ACC_WIDTH-1:0] accumulator, next_acc;
	always_comb begin
		next_acc = signed'(i_psum) + ACC_WIDTH'(mult_r);
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
