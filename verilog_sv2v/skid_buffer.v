`timescale 1ps/1ps
`default_nettype none
module skid_buffer (
	clk,
	rstn,
	i_valid,
	o_ready,
	i_ready,
	o_valid,
	i_data,
	o_data
);
	parameter signed [31:0] N = 32;
	input wire clk;
	input wire rstn;
	input wire i_valid;
	output wire o_ready;
	input wire i_ready;
	output wire o_valid;
	input wire [N - 1:0] i_data;
	output wire [N - 1:0] o_data;
	reg skid_valid_r;
	reg out_valid_r;
	reg [N - 1:0] skid_data_r;
	reg [N - 1:0] out_data_r;
	assign o_ready = !skid_valid_r;
	assign o_valid = out_valid_r;
	assign o_data = out_data_r;
	wire accept_in = i_valid && o_ready;
	wire out_stalled = out_valid_r && !i_ready;
	wire out_free = !out_valid_r || i_ready;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			skid_valid_r <= 1'b0;
		else if (accept_in && out_stalled)
			skid_valid_r <= 1'b1;
		else if (i_ready)
			skid_valid_r <= 1'b0;
	always @(posedge clk)
		if (accept_in)
			skid_data_r <= i_data;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			out_valid_r <= 1'b0;
		else if (out_free)
			out_valid_r <= skid_valid_r || i_valid;
	always @(posedge clk)
		if (out_free) begin
			if (skid_valid_r)
				out_data_r <= skid_data_r;
			else
				out_data_r <= i_data;
		end
endmodule
`default_nettype wire
