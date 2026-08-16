`default_nettype none
`timescale 1ps/1ps
// async assert/sync release reset gen
// leaf distributed to reduce fanout
module reset_gen #(
	parameter integer IO_LEAVES = 4,
	parameter integer DP_LEAVES = 4
)(
	input  wire clk,
	input  wire rstn_async,
	output wire [IO_LEAVES-1:0] rstn_io,
	output wire [DP_LEAVES-1:0] rstn_dp
);
	wire rstn_io_sync;
	wire rstn_dp_sync;

	reset_sync_2ff u_sync_io (
		.i_clk(clk),
		.rstn_src(rstn_async),
		.rstn_sync(rstn_io_sync)
	);

	reset_sync_2ff u_sync_dp (
		.i_clk(clk),
		.rstn_src(rstn_async),
		.rstn_sync(rstn_dp_sync)
	);

	(* keep *) logic [IO_LEAVES-1:0] io_leaf_r;
	(* keep *) logic [DP_LEAVES-1:0] dp_leaf_r;

	always_ff @(posedge clk or negedge rstn_io_sync) begin
		if (!rstn_io_sync)
			io_leaf_r <= '0;
		else
			io_leaf_r <= '1;
	end

	always_ff @(posedge clk or negedge rstn_dp_sync) begin
		if (!rstn_dp_sync)
			dp_leaf_r <= '0;
		else
			dp_leaf_r <= '1;
	end

	assign rstn_io = io_leaf_r;
	assign rstn_dp = dp_leaf_r;

endmodule
`default_nettype wire
