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

	(* keep *)	wire m0_rstb, m0_access_en, m1_rstb, m1_access_en;
	(* keep *)	sram_rst_rel u_rel_m0 (.clk(clk), .rstn(rstn), .o_rstb(m0_rstb), .o_access_en(m0_access_en));
	(* keep *)	sram_rst_rel u_rel_m1 (.clk(clk), .rstn(rstn), .o_rstb(m1_rstb), .o_access_en(m1_access_en));

	(* keep *) logic ping_pong_sel_r;
	(* keep *) logic ping_pong_sel_m0_r;
	(* keep *) logic ping_pong_sel_m1_r;
	logic ping_pong_sel_d1_r;

	(* keep *) logic [31:0] dma_wdata_m0_r, dma_wdata_m1_r;
	logic [3:0] dma_mask_r;
	logic dma_cs_r, dma_we_r;
	logic [5:0] dma_addr_r;

	always_ff @(posedge clk or negedge rstn) begin
	    if (!rstn) begin
	        dma_cs_r <= 1'b0;
	        dma_we_r <= 1'b0;
	    end else begin
	        dma_cs_r <= i_dma_cs;
	        dma_we_r <= i_dma_we;
	    end
	end

	always_ff @(posedge clk) begin
		dma_wdata_m0_r <= i_dma_wdata;
		dma_wdata_m1_r <= i_dma_wdata;
		dma_mask_r  <= i_dma_mask;
		dma_addr_r  <= i_dma_addr;
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			ping_pong_sel_r <= 1'b0;
			ping_pong_sel_m0_r <= 1'b0;
			ping_pong_sel_m1_r <= 1'b0;
			ping_pong_sel_d1_r <= 1'b0;
		end else begin
			if (i_swap) begin
				ping_pong_sel_r <= ~ping_pong_sel_r;
				ping_pong_sel_m0_r <= ~ping_pong_sel_m0_r;
				ping_pong_sel_m1_r <= ~ping_pong_sel_m1_r;
			end
			ping_pong_sel_d1_r <= ping_pong_sel_r;
		end
	end

	assign o_ping_pong_sel = ping_pong_sel_r;

	wire m0_dma = (ping_pong_sel_m0_r == 1'b0);
	wire m1_dma = (ping_pong_sel_m1_r == 1'b1);

	wire m0_ce = m0_access_en && (m0_dma ? dma_cs_r : i_cs_array);
	wire m0_we = m0_dma ? dma_we_r : 1'b0;
	wire [5:0] m0_addr = m0_dma ? dma_addr_r : i_addr_array;

	wire m1_ce = m1_access_en && (m1_dma ? dma_cs_r : i_cs_array);
	wire m1_we = m1_dma ? dma_we_r : 1'b0;
	wire [5:0] m1_addr = m1_dma ? dma_addr_r : i_addr_array;

	sram22_64x32m4w8 u_m0 (
		.clk(clk),
		.rstb(m0_rstb),
		.ce(m0_ce),
		.we(m0_we),
		.wmask(dma_mask_r),
		.addr(m0_addr),
		.din(dma_wdata_m0_r),
		.dout(m0_dout)
	);

	sram22_64x32m4w8 u_m1 (
		.clk(clk),
		.rstb(m1_rstb),
		.ce(m1_ce),
		.we(m1_we),
		.wmask(dma_mask_r),
		.addr(m1_addr),
		.din(dma_wdata_m1_r),
		.dout(m1_dout)
	);

	assign o_array_rdata = (ping_pong_sel_d1_r == 1'b0) ? m1_dout : m0_dout;

endmodule
`default_nettype wire
