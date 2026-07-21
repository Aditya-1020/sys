`default_nettype wire
`timescale 1ps/1ps

module matmul_accel #(
	parameter int unsigned CSR_DATA_W = 32
)(
	`ifdef USE_POWER_PINS
	inout VCCD1,
	inout VSSD1,
	`endif
	input wire clk,
	input wire rstn,

	// CSR channel
	input wire i_csr_wr,
	input wire i_csr_rd,
	input wire [1:0] i_csr_sel,
	input wire [CSR_DATA_W-1:0] i_csr_wdata,
	output wire [CSR_DATA_W-1:0] o_csr_rdata,
	output wire o_csr_rvalid,

	input wire i_host_req,
	input wire i_host_we,
	input wire [7:0] i_host_addr,
	input wire [CSR_DATA_W-1:0] i_host_wdata,
	input wire [3:0] i_host_wmask,
	output wire [CSR_DATA_W-1:0] o_host_rdata,
	output wire o_host_rvalid,

	output wire o_irq
);
	localparam int unsigned TILE = 4;
	localparam int unsigned DATA_WIDTH = 8;
	localparam int unsigned ROW_W = TILE * DATA_WIDTH; // 32
	localparam int unsigned LANE_W = $clog2(TILE);
	localparam int unsigned RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(TILE); // 18

	wire p0_ce_n, p0_we_n, p1_ce_n;
	wire [3:0] p0_wmask;
	wire [7:0] p0_addr, p1_addr;
	wire [31:0] p0_wdata, p0_rdata, p1_rdata;

	wire arr_start, a_valid, b_en, res_ready;
	wire [ROW_W-1:0] a_row, b_wdata;
	wire [LANE_W-1:0] b_lane;
	wire arr_busy, arr_done, res_valid;
	wire [RESULT_WIDTH-1:0] res_data;

	
endmodule
`default_nettype none
