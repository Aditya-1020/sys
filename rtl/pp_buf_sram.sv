`default_nettype none
`timescale 1ps/1ps

module pp_buf_sram (
`ifdef USE_POWER_PINS
	input wire vdd,
	input wire vss,
`endif
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
	
	reg ping_pong_sel_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			ping_pong_sel_r <= 1'b0;
		end else if (i_swap) begin
			ping_pong_sel_r <= ~ping_pong_sel_r;
		end
	end
	assign o_ping_pong_sel = ping_pong_sel_r;

	reg [1:0] sram_rst_rel_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			sram_rst_rel_r <= 2'b00;
		end else begin
			sram_rst_rel_r <= {sram_rst_rel_r[0], 1'b1};
		end
	end

	wire sram_rstb = sram_rst_rel_r[0];
	wire sram_access_en = sram_rst_rel_r[1];

	wire m0_dma = (ping_pong_sel_r == 1'b0);
	wire m0_ce = sram_access_en && (m0_dma ? i_dma_cs : i_cs_array);
	wire m0_we = m0_dma ? i_dma_we : 1'b0;
	wire [5:0] m0_addr = m0_dma ? i_dma_addr : i_addr_array;

	wire m1_ce = sram_access_en && (m0_dma ? i_cs_array : i_dma_cs);
	wire m1_we = m0_dma ? 1'b0 : i_dma_we;
	wire [5:0] m1_addr = m0_dma ? i_addr_array : i_dma_addr;

	sram22_64x32m4w8 u_m0 (
	`ifdef USE_POWER_PINS
		.vdd(vdd),
		.vss(vss),
	`endif
		.clk(clk),
		.rstb(sram_rstb),
		.ce(m0_ce),
		.we(m0_we),
		.wmask(i_dma_mask),
		.addr(m0_addr),
		.din(i_dma_wdata),
		.dout(m0_dout)
	);

	sram22_64x32m4w8 u_m1 (
	`ifdef USE_POWER_PINS
		.vdd(vdd),
		.vss(vss),
	`endif
		.clk(clk),
		.rstb(sram_rstb),
		.ce(m1_ce),
		.we(m1_we),
		.wmask(i_dma_mask),
		.addr(m1_addr),
		.din(i_dma_wdata),
		.dout(m1_dout)
	);

	assign o_array_rdata = m0_dma ? m1_dout : m0_dout;

endmodule
`default_nettype wire
