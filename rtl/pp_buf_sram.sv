`default_nettype none
`timescale 1ps/1ps

module pp_buf_sram (
	input wire clk,
	input wire rstn,
	input wire i_swap, // pulse to swap buffers
	output wire o_ping_pong_sel,

	input wire i_dma_cs,
	input wire i_dma_we,
	input wire [3:0] i_dma_mask,
	input wire [5:0] i_dma_addr, // 64 words per macro
	input wire [31:0] i_dma_wdata,
	input wire i_cs_array, // array chip sel
	input wire [5:0] i_addr_array,
	output wire [31:0] o_array_rdata // output to pes
);
	wire [31:0] m0_dout, m1_dout;
	(* keep *) logic [1:0] rst_sync_r;
	(* keep *) logic [1:0] rst_rel_m0_r;
	(* keep *) logic [1:0] rst_rel_m1_r;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rst_sync_r <= 2'b00;
			rst_rel_m0_r <= 2'b00;
			rst_rel_m1_r <= 2'b00;
		end else begin
			rst_sync_r <= {rst_sync_r[0], 1'b1};
			rst_rel_m0_r <= {rst_rel_m0_r[0], 1'b1};
			rst_rel_m1_r <= {rst_rel_m1_r[0], 1'b1};
		end
	end

	wire rstn_sync = rst_sync_r[1]; // sync resets for all

	wire m0_rstb = rst_rel_m0_r[0];
	wire m0_access_en = rst_rel_m0_r[1];
	wire m1_rstb = rst_rel_m1_r[0];
	wire m1_access_en = rst_rel_m1_r[1];

	(* keep *) logic ping_pong_sel_r;
	(* keep *) logic ping_pong_sel_m0_r;
	(* keep *) logic ping_pong_sel_m1_r;
	logic ping_pong_sel_d1_r;

	always_ff @(posedge clk) begin
		if (!rstn_sync) begin
			ping_pong_sel_r <= 1'b0;
			ping_pong_sel_m0_r <= 1'b0;
			ping_pong_sel_m1_r <= 1'b0;
			ping_pong_sel_d1_r <= 1'b0;
		end else begin
			if (i_swap) begin
				ping_pong_sel_r <= ~ping_pong_sel_r;
				ping_pong_sel_m0_r <= ~ping_pong_sel_m0_r;
				ping_pong_sel_m1_r <= ~ping_pong_sel_m1_r;
			end else begin
				ping_pong_sel_r <= ping_pong_sel_r;
				ping_pong_sel_m0_r <= ping_pong_sel_m0_r;
				ping_pong_sel_m1_r <= ping_pong_sel_m1_r;
			end
			ping_pong_sel_d1_r <= ping_pong_sel_r;
		end
	end

	assign o_ping_pong_sel = ping_pong_sel_r;

	wire m0_dma = (ping_pong_sel_m0_r == 1'b0);
	wire m1_dma = (ping_pong_sel_m1_r == 1'b1);

	wire m0_ce = m0_access_en && (m0_dma ? i_dma_cs : i_cs_array);
	wire m0_we = m0_dma ? i_dma_we : 1'b0;
	wire [5:0] m0_addr = m0_dma ? i_dma_addr : i_addr_array;

	wire m1_ce = m1_access_en && (m1_dma ? i_dma_cs : i_cs_array);
	wire m1_we = m1_dma ? i_dma_we : 1'b0;
	wire [5:0] m1_addr = m1_dma ? i_dma_addr : i_addr_array;

	sram22_64x32m4w8 u_m0 (
		.clk(clk),
		.rstb(m0_rstb),
		.ce(m0_ce),
		.we(m0_we),
		.wmask(i_dma_mask),
		.addr(m0_addr),
		.din(i_dma_wdata),
		.dout(m0_dout)
	);

	sram22_64x32m4w8 u_m1 (
		.clk(clk),
		.rstb(m1_rstb),
		.ce(m1_ce),
		.we(m1_we),
		.wmask(i_dma_mask),
		.addr(m1_addr),
		.din(i_dma_wdata),
		.dout(m1_dout)
	);

	assign o_array_rdata = (ping_pong_sel_d1_r == 1'b0) ? m1_dout : m0_dout;

endmodule
`default_nettype wire
