`default_nettype none
`timescale 1ps/1ps

module skid_buffer #(
	parameter int N = 32
)(
	input wire clk,
	input wire rstn,

	input wire i_valid,
	output wire o_ready,

	input wire i_ready,
	output wire o_valid,

	input wire [N-1:0] i_data,
	output logic [N-1:0] o_data
);

	logic skid_valid_r, out_valid_r;
	logic [N-1:0] skid_data_r, out_data_r;

	assign o_ready = !skid_valid_r;
	assign o_valid = out_valid_r;
	assign o_data = out_data_r;

	wire accept_in = i_valid && o_ready;
	wire out_stalled = out_valid_r && !i_ready;
	wire out_free = !out_valid_r || i_ready;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			skid_valid_r <= 1'b0;
		end else if (skid_valid_r && i_ready) begin
			skid_valid_r <= accept_in;
		end else if (!skid_valid_r && accept_in && out_stalled) begin
			skid_valid_r <= 1'b1;
		end
	end

	always_ff @(posedge clk) begin
		if (accept_in && (skid_valid_r || out_stalled)) begin
			skid_data_r <= i_data;
		end
	end

	// valid out
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			out_valid_r <= 1'b0;
		end else if (out_free) begin
			out_valid_r <= skid_valid_r || i_valid;
		end
	end

	always_ff @(posedge clk) begin
		if (out_free) begin
			if (skid_valid_r) begin
				out_data_r <= skid_data_r;
			end else if (i_valid) begin
				out_data_r <= i_data;
			end
		end
	end

endmodule
`default_nettype wire
