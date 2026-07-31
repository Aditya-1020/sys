`default_nettype none
`timescale 1ps/1ps

module pp_buf_sram (
`ifdef USE_POWER_PINS
	input wire vccd1,
	input wire vssd1,
`endif
	input wire clk,
	input wire rstn,
	input wire i_swap, // pulse to swap buffers
	output wire o_ping_pong_sel,

	input wire i_dma_cs,
	input wire i_dma_we,
	input wire [3:0] i_dma_mask,
	input wire [6:0] i_dma_addr,
	input wire [31:0] i_dma_wdata,
	input wire i_cs_array, // array chip sel
	input wire [6:0] i_addr_array,
	output wire [31:0] o_array_rdata // output to pes
);
	reg ping_pong_sel_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			ping_pong_sel_r <= 1'b0;
		end else if (i_swap) begin
			ping_pong_sel_r <= ~ping_pong_sel_r;
		end
	end

	assign o_ping_pong_sel = ping_pong_sel_r;

	wire [7:0] sram_addr0, sram_addr1;
	assign sram_addr0 = {ping_pong_sel_r, i_dma_addr};
	assign sram_addr1 = {~ping_pong_sel_r, i_addr_array};

	wire csb0_w = ~i_dma_cs;
	wire web0_w = ~i_dma_we;
	wire csb1_w = ~i_cs_array;

	sky130_sram_1kbyte_1rw1r_32x256_8 sky_sram_cell (
	`ifdef USE_POWER_PINS
		.vccd1(vccd1),
		.vssd1(vssd1),
	`endif
		// Port 0: RW
		.clk0 (clk),
		.csb0 (csb0_w),
		.web0 (web0_w),
		.wmask0(i_dma_mask),
		.addr0(sram_addr0),
		.din0 (i_dma_wdata),
		.dout0(),

		// Port 1: R
		.clk1 (clk),
		.csb1 (csb1_w),
		.addr1(sram_addr1),
		.dout1(o_array_rdata)
	);

endmodule
`default_nettype wire
