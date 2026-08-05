`default_nettype none
`timescale 1ps/1ps

module pe #(
	parameter integer DATA_WIDTH = 8,
	parameter integer MATRIX_SIZE = 4,
	parameter integer ACC_WIDTH = 2*DATA_WIDTH + $clog2(MATRIX_SIZE)
)(
	input wire clk,
	input wire rstn,
	input wire i_enable, // compute
	input wire i_w_load,
	input wire signed [DATA_WIDTH-1:0] i_a,
	input wire signed [DATA_WIDTH-1:0] i_b,
	input wire signed [ACC_WIDTH-1:0] i_psum,
	output wire signed [DATA_WIDTH-1:0] o_a,
	output wire signed [ACC_WIDTH-1:0] o_psum,
	output wire o_enable
);
	logic signed [DATA_WIDTH-1:0] a_r; // pass through only
	always_ff @(posedge clk) begin
		if (i_enable) begin
			a_r <= i_a;
		end
	end

	logic en_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			en_r <= 1'b0;
		end else begin
			en_r <= i_enable;
		end
	end

	// weight stationary (clear unless reloaded)
	logic signed [DATA_WIDTH-1:0] w_r;
	always_ff @(posedge clk) begin
		if (i_w_load) begin
			w_r <= i_b;
		end
	end

	// logic signed [2*DATA_WIDTH-1:0] mult_w; // 16 bit
	// assign mult_w = a_r * w_r;

	logic signed [2*DATA_WIDTH-1:0] mult_pipe;
	always_ff @(posedge clk) begin
		mult_pipe <= a_r * w_r;
	end

	logic signed [2*DATA_WIDTH-1:0] mult_r;
	always_ff @(posedge clk) begin
		if (i_enable) begin
			mult_r <= mult_pipe;
		end
	end

	logic signed [ACC_WIDTH-1:0] accumulator;
	wire signed [ACC_WIDTH-1:0] next_acc;
	assign next_acc = i_psum + ACC_WIDTH'(mult_r);

	always_ff @(posedge clk) begin
		if (i_enable) begin
			accumulator <= next_acc;
		end
	end

	assign o_psum = accumulator;
	assign o_a = a_r;
	assign o_enable = en_r;

endmodule
`default_nettype wire
