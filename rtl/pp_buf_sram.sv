`default_nettype none
`timescale 1ps/1ps

module pp_buf_sram (
	input wire clk,
	input wire rstn,
	input wire i_swap, // pulse to swap buffers
	output wire o_ping_pong_sel,

	input wire i_dma_cs,
	input wire i_dma_we,
	input wire [5:0] i_dma_addr, // 64 words per macro
	input wire [31:0] i_dma_wdata,
	input wire i_cs_array, // array chip sel
	input wire [5:0] i_addr_array,
	output wire [31:0] o_array_rdata // output to pes
);
	localparam logic [3:0] DMA_WMASK = sys_pkg::AXI_SRAM_DMA_MASK;

	wire [31:0] m0_dout, m1_dout;

	(* keep *) logic [1:0] m0_rel_r;
	(* keep *) logic m1_rel_a, m1_rel_b;
	(* keep *) wire m0_rstb, m0_access_en, m1_rstb, m1_access_en;

	always_ff @(posedge clk) begin
		if (!rstn) begin
			m0_rel_r <= 2'b00;
		end else begin
			m0_rel_r <= {m0_rel_r[0], 1'b1};
		end
	end

	assign m0_rstb = m0_rel_r[0];
	assign m0_access_en = m0_rel_r[1];

	always_ff @(posedge clk) begin
		if (!rstn) begin
			m1_rel_a <= 1'b0;
			m1_rel_b <= 1'b0;
		end else begin
			m1_rel_a <= m1_rel_a | 1'b1;
			m1_rel_b <= m1_rel_a;
		end
	end

	assign m1_rstb = m1_rel_b;
	assign m1_access_en = m1_rel_a & m1_rel_b;

	(* keep *) logic ping_pong_sel_r;
	(* keep *) logic ping_pong_sel_m0_r;
	(* keep *) logic ping_pong_sel_m1_r;
	logic ping_pong_sel_d1_r;

	(* keep *) logic [31:0] dma_wdata_m0_r, dma_wdata_m1_r;
	logic dma_cs_r, dma_we_r;
	logic [5:0] dma_addr_r;

	wire m0_dma_sel = !ping_pong_sel_m0_r;
	wire m1_dma_sel = ping_pong_sel_m1_r;
	wire m0_wdata_en = i_dma_cs && i_dma_we && m0_dma_sel;
	wire m1_wdata_en = i_dma_cs && i_dma_we && m1_dma_sel;

	always_ff @(posedge clk) begin
	    if (!rstn) begin
	        dma_cs_r <= 1'b0;
	        dma_we_r <= 1'b0;
	    end else begin
	        dma_cs_r <= i_dma_cs;
	        dma_we_r <= i_dma_we;
	    end
	end

	always_ff @(posedge clk) begin
		dma_addr_r <= i_dma_addr;
		if (m0_wdata_en) begin
			dma_wdata_m0_r <= i_dma_wdata;
		end
		if (m1_wdata_en) begin
			dma_wdata_m1_r <= i_dma_wdata;
		end
	end

	always_ff @(posedge clk) begin
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

	wire m0_dma = m0_dma_sel;
	wire m1_dma = m1_dma_sel;

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
		.wmask(DMA_WMASK),
		.addr(m0_addr),
		.din(dma_wdata_m0_r),
		.dout(m0_dout)
	);

	sram22_64x32m4w8 u_m1 (
		.clk(clk),
		.rstb(m1_rstb),
		.ce(m1_ce),
		.we(m1_we),
		.wmask(DMA_WMASK),
		.addr(m1_addr),
		.din(dma_wdata_m1_r),
		.dout(m1_dout)
	);

	logic [31:0] array_rdata_r;
	always_ff @(posedge clk) begin
		array_rdata_r <= (ping_pong_sel_d1_r == 1'b0) ? m1_dout : m0_dout;
	end
	assign o_array_rdata = array_rdata_r;

endmodule
`default_nettype wire
