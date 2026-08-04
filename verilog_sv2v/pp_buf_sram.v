`timescale 1ps/1ps
`default_nettype none
module pp_buf_sram (
	clk,
	rstn,
	i_swap,
	o_ping_pong_sel,
	i_dma_cs,
	i_dma_we,
	i_dma_mask,
	i_dma_addr,
	i_dma_wdata,
	i_cs_array,
	i_addr_array,
	o_array_rdata
);
	input wire clk;
	input wire rstn;
	input wire i_swap;
	output wire o_ping_pong_sel;
	input wire i_dma_cs;
	input wire i_dma_we;
	input wire [3:0] i_dma_mask;
	input wire [5:0] i_dma_addr;
	input wire [31:0] i_dma_wdata;
	input wire i_cs_array;
	input wire [5:0] i_addr_array;
	output wire [31:0] o_array_rdata;
	wire [31:0] m0_dout;
	wire [31:0] m1_dout;
	reg ping_pong_sel_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			ping_pong_sel_r <= 1'b0;
		else if (i_swap)
			ping_pong_sel_r <= ~ping_pong_sel_r;
	assign o_ping_pong_sel = ping_pong_sel_r;
	wire m0_dma = ping_pong_sel_r == 1'b0;
	wire m0_ce = (m0_dma ? i_dma_cs : i_cs_array);
	wire m0_we = (m0_dma ? i_dma_we : 1'b0);
	wire [5:0] m0_addr = (m0_dma ? i_dma_addr : i_addr_array);
	wire m1_ce = (m0_dma ? i_cs_array : i_dma_cs);
	wire m1_we = (m0_dma ? 1'b0 : i_dma_we);
	wire [5:0] m1_addr = (m0_dma ? i_addr_array : i_dma_addr);
	sram22_64x32m4w8 u_m0(
		.clk(clk),
		.rstb(rstn),
		.ce(m0_ce),
		.we(m0_we),
		.wmask(i_dma_mask),
		.addr(m0_addr),
		.din(i_dma_wdata),
		.dout(m0_dout)
	);
	sram22_64x32m4w8 u_m1(
		.clk(clk),
		.rstb(rstn),
		.ce(m1_ce),
		.we(m1_we),
		.wmask(i_dma_mask),
		.addr(m1_addr),
		.din(i_dma_wdata),
		.dout(m1_dout)
	);
	assign o_array_rdata = (m0_dma ? m1_dout : m0_dout);
endmodule
`default_nettype wire
