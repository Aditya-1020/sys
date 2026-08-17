`default_nettype none
`timescale 1ps/1ps

module top #(
	parameter integer AXI_ADDR_W = sys_pkg::AXI_ADDR_W,
	parameter integer AXI_DATA_W = sys_pkg::AXI_DATA_W
)(
	input wire clk,
	input wire rstn,

	input wire [7:0] i_s_axil_awaddr,
	input wire i_s_axil_awvalid,
	output wire o_s_axil_awready,
	input wire [31:0] i_s_axil_wdata,
	input wire [3:0]  i_s_axil_wstrb,
	input wire i_s_axil_wvalid,
	output wire o_s_axil_wready,
	output wire [1:0] o_s_axil_bresp,
	output wire o_s_axil_bvalid,
	input wire i_s_axil_bready,
	input wire [7:0] i_s_axil_araddr,
	input wire i_s_axil_arvalid,
	output wire o_s_axil_arready,
	output wire [31:0] o_s_axil_rdata,
	output wire [1:0] o_s_axil_rresp,
	output wire o_s_axil_rvalid,
	input wire i_s_axil_rready,

	output wire [AXI_ADDR_W-1:0] o_m_axi_araddr,
	output wire [7:0] o_m_axi_arlen,
	output wire o_m_axi_arvalid,
	input wire i_m_axi_arready,
	input wire [AXI_DATA_W-1:0] i_m_axi_rdata,
	input wire [1:0] i_m_axi_rresp,
	input wire i_m_axi_rlast,
	input wire i_m_axi_rvalid,
	output wire o_m_axi_rready,

	output wire [AXI_ADDR_W-1:0] o_m_axi_awaddr,
	output wire o_m_axi_awvalid,
	input wire i_m_axi_awready,
	output wire [AXI_DATA_W-1:0] o_m_axi_wdata,
	output wire o_m_axi_wlast,
	output wire o_m_axi_wvalid,
	input wire i_m_axi_wready,
	input wire [1:0] i_m_axi_bresp,
	input wire i_m_axi_bvalid,
	output wire o_m_axi_bready
);
	import sys_pkg::*;

	localparam integer MATRIX_SIZE = sys_pkg::MATRIX_SIZE;
	localparam integer DATA_WIDTH = sys_pkg::DATA_WIDTH;
	localparam integer RESULT_W = sys_pkg::RESULT_W;
	localparam integer LEVEL_W = sys_pkg::LEVEL_W;
	localparam integer TILE_BEATS = sys_pkg::TILE_BEATS;
	localparam integer TILE_BYTES = sys_pkg::TILE_BYTES;
	localparam integer ST_TILE_LSB = sys_pkg::ST_TILE_LSB;
	localparam integer CTRL_EN = sys_pkg::CTRL_EN;
	localparam integer CTRL_GO = sys_pkg::CTRL_GO;
	localparam integer CTRL_LOAD_W = sys_pkg::CTRL_LOAD_W;
	localparam integer CTRL_STORE = sys_pkg::CTRL_STORE;
	localparam integer CTRL_AUTO_ST = sys_pkg::CTRL_AUTO_ST;
	localparam integer CTRL_AUTO_FILL = sys_pkg::CTRL_AUTO_FILL;
	localparam integer ST_DMA_BUSY = sys_pkg::ST_DMA_BUSY;
	localparam integer ST_DMA_DONE = sys_pkg::ST_DMA_DONE;
	localparam integer ST_DMA_ERR = sys_pkg::ST_DMA_ERR;
	localparam integer ST_FILL_DONE = sys_pkg::ST_FILL_DONE;
	localparam integer ST_CTRL_BUSY = sys_pkg::ST_CTRL_BUSY;
	localparam integer ST_ARRAY_BUSY = sys_pkg::ST_ARRAY_BUSY;
	localparam integer ST_ARRAY_DONE = sys_pkg::ST_ARRAY_DONE;
	localparam integer ST_PP_SEL = sys_pkg::ST_PP_SEL;
	localparam integer ST_W_VALID = sys_pkg::ST_W_VALID;
	localparam integer ST_RES_VALID = sys_pkg::ST_RES_VALID;
	localparam integer ST_RES_OVF = sys_pkg::ST_RES_OVF;
	localparam integer ST_WDMA_BUSY = sys_pkg::ST_WDMA_BUSY;
	localparam integer ST_WDMA_DONE = sys_pkg::ST_WDMA_DONE;
	localparam integer ST_WDMA_ERR = sys_pkg::ST_WDMA_ERR;
	localparam integer ST_AF_BUSY = sys_pkg::ST_AF_BUSY;
	localparam integer ST_LEVEL_LSB = sys_pkg::ST_LEVEL_LSB;

	wire [3:0] rstn_io;
	wire [3:0] rstn_dp;
	reset_gen u_reset_gen (
		.clk(clk),
		.rstn_async(rstn),
		.rstn_io(rstn_io),
		.rstn_dp(rstn_dp)
	);

	wire [31:0] csr_ctrl, csr_src_addr, csr_len, csr_dst_addr, csr_njobs, csr_status;
	wire dma_busy, dma_done, dma_err, dma_fill_done, dma_swap, array_release;
	wire dma_cs, dma_we;
	wire [SRAM_ADDR_W-1:0] dma_addr;
	wire [ROW_W-1:0] dma_wdata;
	wire arr_ctrl_cs_p1;
	wire [SRAM_ADDR_W-1:0] arr_ctrl_addr;
	wire [ROW_W-1:0] sram_rdata;
	wire arr_ctrl_b_en, arr_ctrl_a_valid;
	wire [LANE_W-1:0] arr_ctrl_b_lane;
	wire [ROW_W-1:0] arr_ctrl_b_wdata, arr_ctrl_ld_a;
	wire arr_ctrl_busy, arr_ctrl_w_valid, ping_pong_sel, arr_reserve;
	wire array_done, array_busy;
	wire [MATRIX_SIZE*RESULT_W-1:0] arr_result_data;
	wire [MATRIX_SIZE-1:0] arr_result_valid;
	wire fifo_room, fifo_valid, fifo_overflow, fifo_rd;
	wire [AXI_DATA_W-1:0] fifo_rdata;
	wire [LEVEL_W-1:0] fifo_level;
	wire wdma_busy, wdma_done, wdma_err, wdma_resp, wdma_last_beat, wdma_fifo_rd, csr_result_rd;
	wire dma_start, wdma_start;
	wire [31:0] dma_src, wdma_dst;
	wire [31:0] csr_result = fifo_rdata;

	assign fifo_rd = wdma_busy ? wdma_fifo_rd : csr_result_rd;

	sys_ctrl u_sys_ctrl (
		.clk(clk),
		.rstn(rstn_io[3]),
		.csr_ctrl(csr_ctrl),
		.csr_src_addr(csr_src_addr),
		.csr_len(csr_len),
		.csr_dst_addr(csr_dst_addr),
		.csr_njobs(csr_njobs),
		.dma_busy(dma_busy),
		.dma_done(dma_done),
		.dma_err(dma_err),
		.dma_fill_done(dma_fill_done),
		.wdma_busy(wdma_busy),
		.wdma_done(wdma_done),
		.wdma_err(wdma_err),
		.wdma_resp(wdma_resp),
		.wdma_last_beat(wdma_last_beat),
		.arr_ctrl_busy(arr_ctrl_busy),
		.arr_ctrl_w_valid(arr_ctrl_w_valid),
		.array_busy(array_busy),
		.array_done(array_done),
		.ping_pong_sel(ping_pong_sel),
		.fifo_valid(fifo_valid),
		.fifo_overflow(fifo_overflow),
		.fifo_level(fifo_level),
		.ar_fire(o_m_axi_arvalid & i_m_axi_arready),
		.aw_fire(o_m_axi_awvalid & i_m_axi_awready),
		.o_dma_start(dma_start),
		.o_dma_src(dma_src),
		.o_wdma_start(wdma_start),
		.o_wdma_dst(wdma_dst),
		.o_csr_status(csr_status)
	);

	axi_lite_csr u_csr (
		.aclk(clk),
		.aresetn(rstn_io[0]),
		.i_s_axil_awaddr(i_s_axil_awaddr),
		.i_s_axil_awvalid(i_s_axil_awvalid),
		.o_s_axil_awready(o_s_axil_awready),
		.i_s_axil_wdata(i_s_axil_wdata),
		.i_s_axil_wstrb(i_s_axil_wstrb),
		.i_s_axil_wvalid(i_s_axil_wvalid),
		.o_s_axil_wready(o_s_axil_wready),
		.o_s_axil_bresp(o_s_axil_bresp),
		.o_s_axil_bvalid(o_s_axil_bvalid),
		.i_s_axil_bready(i_s_axil_bready),
		.i_s_axil_araddr(i_s_axil_araddr),
		.i_s_axil_arvalid(i_s_axil_arvalid),
		.o_s_axil_arready(o_s_axil_arready),
		.o_s_axil_rdata(o_s_axil_rdata),
		.o_s_axil_rresp(o_s_axil_rresp),
		.o_s_axil_rvalid(o_s_axil_rvalid),
		.i_s_axil_rready(i_s_axil_rready),
		.i_fifo_valid(fifo_valid),
		.csr_status(csr_status),
		.csr_result(csr_result),
		.csr_result_rd(csr_result_rd),
		.csr_ctrl(csr_ctrl),
		.csr_src_addr(csr_src_addr),
		.csr_len(csr_len),
		.csr_dst_addr(csr_dst_addr),
		.csr_njobs(csr_njobs)
	);

	axi4_dma_wr #(.AXI_ADDR_W(AXI_ADDR_W), .BEATS(TILE_BEATS)) u_wdma (
		.clk(clk),
		.rstn(rstn_io[2]),
		.i_dst_addr(wdma_dst),
		.i_start(wdma_start),
		.o_busy(wdma_busy),
		.o_resp(wdma_resp),
		.o_last_beat(wdma_last_beat),
		.o_done(wdma_done),
		.o_err(wdma_err),
		.o_m_awaddr(o_m_axi_awaddr),
		.o_m_awvalid(o_m_axi_awvalid),
		.i_m_awready(i_m_axi_awready),
		.o_m_wdata(o_m_axi_wdata),
		.o_m_wlast(o_m_axi_wlast),
		.o_m_wvalid(o_m_axi_wvalid),
		.i_m_wready(i_m_axi_wready),
		.i_m_bresp(i_m_axi_bresp),
		.i_m_bvalid(i_m_axi_bvalid),
		.o_m_bready(o_m_axi_bready),
		.i_fifo_valid(fifo_valid),
		.i_fifo_rdata(csr_result),
		.o_fifo_rd(wdma_fifo_rd)
	);

	axi4_dma #(.AXI_ADDR_W(AXI_ADDR_W), .SRAM_ADDR_W(SRAM_ADDR_W)) u_dma (
		.clk(clk),
		.rstn(rstn_io[1]),
		.i_src_addr(dma_src),
		.i_len(csr_len[LEN_W-1:0]),
		.i_start(dma_start),
		.o_busy(dma_busy),
		.o_done(dma_done),
		.o_err(dma_err),
		.o_m_araddr(o_m_axi_araddr),
		.o_m_arlen(o_m_axi_arlen),
		.o_m_arvalid(o_m_axi_arvalid),
		.i_m_arready(i_m_axi_arready),
		.i_m_rdata(i_m_axi_rdata),
		.i_m_rresp(i_m_axi_rresp),
		.i_m_rlast(i_m_axi_rlast),
		.i_m_rvalid(i_m_axi_rvalid),
		.o_m_rready(o_m_axi_rready),
		.o_dma_cs(dma_cs),
		.o_dma_we(dma_we),
		.o_dma_addr(dma_addr),
		.o_dma_wdata(dma_wdata),
		.o_swap(dma_swap),
		.o_fill_done(dma_fill_done),
		.i_array_done(array_release)
	);

	pp_buf_sram u_sram (
		.clk(clk),
		.rstn(rstn_dp[0]),
		.i_swap(dma_swap),
		.o_ping_pong_sel(ping_pong_sel),
		.i_dma_cs(dma_cs),
		.i_dma_we(dma_we),
		.i_dma_addr(dma_addr),
		.i_dma_wdata(dma_wdata),
		.i_cs_array(arr_ctrl_cs_p1),
		.i_addr_array(arr_ctrl_addr),
		.o_array_rdata(sram_rdata)
	);

	array_control #(.MATRIX_SIZE(MATRIX_SIZE), .DATA_WIDTH(DATA_WIDTH), .SRAM_ADDR_W(SRAM_ADDR_W)) u_arr_ctrl (
		.clk(clk),
		.rstn(rstn_dp[1]),
		.i_enable(csr_ctrl[CTRL_EN]),
		.i_load_w(csr_ctrl[CTRL_LOAD_W]),
		.i_len(csr_len[LEN_W-1:0]),
		.i_room(fifo_room),
		.i_fill_done(dma_fill_done),
		.o_array_done(array_release),
		.o_cs_array(arr_ctrl_cs_p1),
		.o_addr_array(arr_ctrl_addr),
		.i_array_rdata(sram_rdata),
		.o_b_en(arr_ctrl_b_en),
		.o_b_lane(arr_ctrl_b_lane),
		.o_b_wdata(arr_ctrl_b_wdata),
		.o_a_valid(arr_ctrl_a_valid),
		.o_ld_a(arr_ctrl_ld_a),
		.i_array_busy(array_busy),
		.o_reserve(arr_reserve),
		.o_busy(arr_ctrl_busy),
		.o_w_valid(arr_ctrl_w_valid)
	);

	systolic_array #(.MATRIX_SIZE(MATRIX_SIZE), .DATA_WIDTH(DATA_WIDTH)) u_array (
		.clk(clk),
		.rstn(rstn_dp[2]),
		.i_a_valid(arr_ctrl_a_valid),
		.i_ld_a(arr_ctrl_ld_a),
		.i_b_en(arr_ctrl_b_en),
		.i_b_lane(arr_ctrl_b_lane),
		.i_b_wdata(arr_ctrl_b_wdata),
		.o_result_data(arr_result_data),
		.o_result_valid(arr_result_valid),
		.o_done(array_done),
		.o_busy(array_busy)
	);

	res_cap_fifo #(.MATRIX_SIZE(MATRIX_SIZE), .DATA_WIDTH(DATA_WIDTH), .BEAT_W(AXI_DATA_W), .JOBS(RES_JOBS)) u_res_fifo (
		.clk(clk),
		.rstn(rstn_dp[3]),
		.i_result_valid(arr_result_valid),
		.i_result_data(arr_result_data),
		.i_reserve(arr_reserve),
		.o_room(fifo_room),
		.rd_en(fifo_rd),
		.o_rdata(fifo_rdata),
		.o_valid(fifo_valid),
		.o_level(fifo_level),
		.o_overflow(fifo_overflow)
	);

endmodule
`default_nettype wire
