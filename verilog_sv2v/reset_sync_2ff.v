`timescale 1ps/1ps
`default_nettype none
module reset_sync_2ff (
	i_clk,
	rstn_src,
	rstn_sync
);
	input wire i_clk;
	input wire rstn_src;
	output wire rstn_sync;
	reg [1:0] sync_reg;
	always @(posedge i_clk or negedge rstn_src)
		if (!rstn_src)
			sync_reg <= 2'b00;
		else
			sync_reg <= {sync_reg[0], 1'b1};
	assign rstn_sync = sync_reg[1];
endmodule
`default_nettype wire
