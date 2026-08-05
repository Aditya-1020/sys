`default_nettype none
`timescale 1ps/1ps

module top #(
	parameter integer AXI_ADDR_W = 32,
	parameter integer AXI_DATA_W = 32
)(
	`ifdef USE_POWER_PINS
		inout vdd,
		inout vss,
	`endif
	input wire clk,
	input wire rstn,

	// axilite slave (csr cpu)
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

	// axi master read
	output wire [3:0] o_m_axi_arid,
	output wire [AXI_ADDR_W-1:0] o_m_axi_araddr,
	output wire [7:0] o_m_axi_arlen,
	output wire [2:0] o_m_axi_arsize,
	output wire [1:0] o_m_axi_arburst,
	output wire o_m_axi_arlock,
	output wire [3:0] o_m_axi_arcache,
	output wire [2:0] o_m_axi_arprot,
	output wire o_m_axi_arvalid,
	input wire i_m_axi_arready,

	input wire [AXI_DATA_W-1:0] i_m_axi_rdata,
	input wire [1:0] i_m_axi_rresp,
	input wire i_m_axi_rlast,
	input wire i_m_axi_rvalid,
	output wire o_m_axi_rready,

	// axi master write (result store)
	output wire [3:0] o_m_axi_awid,
	output wire [AXI_ADDR_W-1:0] o_m_axi_awaddr,
	output wire [7:0] o_m_axi_awlen,
	output wire [2:0] o_m_axi_awsize,
	output wire [1:0] o_m_axi_awburst,
	output wire o_m_axi_awlock,
	output wire [3:0] o_m_axi_awcache,
	output wire [2:0] o_m_axi_awprot,
	output wire o_m_axi_awvalid,
	input wire i_m_axi_awready,

	output wire [AXI_DATA_W-1:0] o_m_axi_wdata,
	output wire [3:0] o_m_axi_wstrb,
	output wire o_m_axi_wlast,
	output wire o_m_axi_wvalid,
	input wire i_m_axi_wready,

	input wire [1:0] i_m_axi_bresp,
	input wire i_m_axi_bvalid,
	output wire o_m_axi_bready
);
	localparam integer MATRIX_SIZE = 4;
	localparam integer DATA_WIDTH = 8;
	localparam integer ROW_W = MATRIX_SIZE * DATA_WIDTH; // 32
	localparam integer LANE_W = $clog2(MATRIX_SIZE); // 2
	localparam integer RESULT_W = (2 * DATA_WIDTH) + $clog2(MATRIX_SIZE); // 18
	localparam integer SRAM_ADDR_W = 6;
	localparam integer LEN_W = SRAM_ADDR_W + 1;

	// CTRL bit map (0x00)
	localparam integer CTRL_EN = 0; // array enable
	localparam integer CTRL_GO = 1; // rising edge launches one dma job
	localparam integer CTRL_LOAD_W = 2; // reload stationary weights this job
	localparam integer CTRL_STORE = 3; // rising edge stores one c tile to dst
	localparam integer CTRL_AUTO_ST = 4; // hw self-launches a store per completed tile

	// STATUS bit map (0x04)
	localparam integer ST_DMA_BUSY = 0;
	localparam integer ST_DMA_DONE = 1;
	localparam integer ST_DMA_ERR = 2; // len mismatch or rresp err
	localparam integer ST_FILL_DONE = 3; // half filled, waiting on swap
	localparam integer ST_CTRL_BUSY = 4;
	localparam integer ST_ARRAY_BUSY = 5;
	localparam integer ST_ARRAY_DONE = 6;
	localparam integer ST_PP_SEL = 7; // which half the dma owns
	localparam integer ST_W_VALID = 8; // weights resident
	localparam integer ST_RES_VALID = 9; // at least one result poppable
	localparam integer ST_RES_OVF = 10;
	localparam integer ST_WDMA_BUSY = 11;
	localparam integer ST_WDMA_DONE = 12;
	localparam integer ST_WDMA_ERR = 13; // bresp err
	localparam integer ST_LEVEL_LSB = 16; // [21:16] fifo level
	localparam integer ST_TILE_LSB = 22;

	wire resetn_synced;
	reset_sync_2ff u_rsync (
		.i_clk(clk),
		.rstn_src(rstn),
		.rstn_sync(resetn_synced)
	);

	wire [31:0] csr_ctrl, csr_src_addr, csr_len, csr_dst_addr;
	logic [31:0] csr_status;

	logic go_r, store_r, auto_st_r;
	always_ff @(posedge clk or negedge resetn_synced) begin
		if (!resetn_synced) begin
			go_r <= 1'b0;
			store_r <= 1'b0;
			auto_st_r <= 1'b0;
		end else begin
			go_r <= csr_ctrl[CTRL_GO];
			store_r <= csr_ctrl[CTRL_STORE];
			auto_st_r <= csr_ctrl[CTRL_AUTO_ST];
		end
	end
	wire dma_start = csr_ctrl[CTRL_GO] && !go_r;
	wire wdma_start_manual = csr_ctrl[CTRL_STORE] && !store_r;
	wire auto_st_en = csr_ctrl[CTRL_AUTO_ST];
	wire auto_st_arm = auto_st_en && !auto_st_r; // enable rising edge reloads the pointer

	wire dma_busy, dma_done, dma_err;
	wire dma_fill_done, dma_swap;
	wire array_release;

	wire dma_cs, dma_we;
	wire [3:0] dma_mask;
	wire [SRAM_ADDR_W-1:0] dma_addr;
	wire [ROW_W-1:0] dma_wdata;

	wire arr_ctrl_cs_p1; // sram port 1
	wire [SRAM_ADDR_W-1:0] arr_ctrl_addr;
	wire [ROW_W-1:0] sram_rdata;

	wire arr_ctrl_start, arr_ctrl_b_en, arr_ctrl_a_valid;
	wire [LANE_W-1:0] arr_ctrl_b_lane;
	wire [ROW_W-1:0] arr_ctrl_b_wdata, arr_ctrl_ld_a;

	wire arr_ctrl_busy, arr_ctrl_w_valid, ping_pong_sel;
	wire array_done, array_busy;

	// result capture path
	wire [MATRIX_SIZE*RESULT_W-1:0] arr_result_data;
	wire [MATRIX_SIZE-1:0] arr_result_valid;
	wire fifo_room, fifo_valid, fifo_overflow, fifo_rd;
	wire signed [RESULT_W-1:0] fifo_rdata;
	wire [5:0] fifo_level;

	wire [31:0] csr_result = {{(32-RESULT_W){fifo_rdata[RESULT_W-1]}}, fifo_rdata}; // extend csr readback

	// result store dma
	wire wdma_busy, wdma_done, wdma_err, wdma_fifo_rd, csr_result_rd;
	assign fifo_rd = wdma_busy ? wdma_fifo_rd : csr_result_rd;

	// result store
	localparam integer TILE_BEATS = MATRIX_SIZE * MATRIX_SIZE; // 16
	localparam integer TILE_BYTES = TILE_BEATS * 4; // 64, one INCR burst

	wire tile_ready = (fifo_level >= 6'(TILE_BEATS));
	wire wdma_start = wdma_start_manual || (auto_st_en && tile_ready && !wdma_busy);

	logic [31:0] dst_ptr_r;
	wire [31:0] wdma_dst = auto_st_en ? dst_ptr_r : csr_dst_addr;
	always_ff @(posedge clk or negedge resetn_synced) begin
		if (!resetn_synced) begin
			dst_ptr_r <= '0;
		end else if (auto_st_arm) begin
			dst_ptr_r <= csr_dst_addr;
		end else if (wdma_start) begin
			dst_ptr_r <= wdma_dst + 32'(TILE_BYTES);
		end
	end

	logic wdma_done_r;
	always_ff @(posedge clk or negedge resetn_synced) begin
		if (!resetn_synced) wdma_done_r <= 1'b0;
		else wdma_done_r <= wdma_done;
	end
	wire wdma_done_edge = wdma_done && !wdma_done_r;

	logic [3:0] tile_cnt_r;
	always_ff @(posedge clk or negedge resetn_synced) begin
		if (!resetn_synced) begin
			tile_cnt_r <= '0;
		end else if (auto_st_arm) begin
			tile_cnt_r <= '0;
		end else if (wdma_done_edge) begin
			tile_cnt_r <= tile_cnt_r + 1'b1;
		end
	end

	always_comb begin
		csr_status = '0;
		csr_status[ST_DMA_BUSY] = dma_busy;
		csr_status[ST_DMA_DONE] = dma_done;
		csr_status[ST_DMA_ERR] = dma_err;
		csr_status[ST_FILL_DONE] = dma_fill_done;
		csr_status[ST_CTRL_BUSY] = arr_ctrl_busy;
		csr_status[ST_ARRAY_BUSY] = array_busy;
		csr_status[ST_ARRAY_DONE] = array_done;
		csr_status[ST_PP_SEL] = ping_pong_sel;
		csr_status[ST_W_VALID] = arr_ctrl_w_valid;
		csr_status[ST_RES_VALID] = fifo_valid;
		csr_status[ST_RES_OVF] = fifo_overflow;
		csr_status[ST_WDMA_BUSY] = wdma_busy;
		csr_status[ST_WDMA_DONE] = wdma_done;
		csr_status[ST_WDMA_ERR] = wdma_err;
		csr_status[ST_LEVEL_LSB +: 6] = fifo_level;
		csr_status[ST_TILE_LSB +: 4] = tile_cnt_r;
	end

	axi_lite_csr u_csr (
		.aclk            (clk),
		.aresetn         (resetn_synced),
		.i_s_axil_awaddr (i_s_axil_awaddr),
		.i_s_axil_awvalid(i_s_axil_awvalid),
		.o_s_axil_awready(o_s_axil_awready),
		.i_s_axil_wdata  (i_s_axil_wdata),
		.i_s_axil_wstrb  (i_s_axil_wstrb),
		.i_s_axil_wvalid (i_s_axil_wvalid),
		.o_s_axil_wready (o_s_axil_wready),
		.o_s_axil_bresp  (o_s_axil_bresp),
		.o_s_axil_bvalid (o_s_axil_bvalid),
		.i_s_axil_bready (i_s_axil_bready),
		.i_s_axil_araddr (i_s_axil_araddr),
		.i_s_axil_arvalid(i_s_axil_arvalid),
		.o_s_axil_arready(o_s_axil_arready),
		.o_s_axil_rdata  (o_s_axil_rdata),
		.o_s_axil_rresp  (o_s_axil_rresp),
		.o_s_axil_rvalid (o_s_axil_rvalid),
		.i_s_axil_rready (i_s_axil_rready),
		.i_fifo_valid    (fifo_valid),
		.csr_status      (csr_status),
		.csr_result      (csr_result),
		.csr_result_rd   (csr_result_rd),
		.csr_ctrl        (csr_ctrl),
		.csr_src_addr    (csr_src_addr),
		.csr_len         (csr_len),
		.csr_dst_addr    (csr_dst_addr)
	);

	axi4_dma_wr #(
		.AXI_ADDR_W (AXI_ADDR_W),
		.BEATS      (MATRIX_SIZE*MATRIX_SIZE)
	) u_wdma (
		.clk          (clk),
		.rstn         (resetn_synced),
		.i_dst_addr   (wdma_dst),
		.i_start      (wdma_start),
		.o_busy       (wdma_busy),
		.o_done       (wdma_done),
		.o_err        (wdma_err),
		.o_m_awid     (o_m_axi_awid),
		.o_m_awaddr   (o_m_axi_awaddr),
		.o_m_awlen    (o_m_axi_awlen),
		.o_m_awsize   (o_m_axi_awsize),
		.o_m_awburst  (o_m_axi_awburst),
		.o_m_awlock   (o_m_axi_awlock),
		.o_m_awcache  (o_m_axi_awcache),
		.o_m_awprot   (o_m_axi_awprot),
		.o_m_awvalid  (o_m_axi_awvalid),
		.i_m_awready  (i_m_axi_awready),
		.o_m_wdata    (o_m_axi_wdata),
		.o_m_wstrb    (o_m_axi_wstrb),
		.o_m_wlast    (o_m_axi_wlast),
		.o_m_wvalid   (o_m_axi_wvalid),
		.i_m_wready   (i_m_axi_wready),
		.i_m_bresp    (i_m_axi_bresp),
		.i_m_bvalid   (i_m_axi_bvalid),
		.o_m_bready   (o_m_axi_bready),
		.i_fifo_valid (fifo_valid),
		.i_fifo_rdata (csr_result),
		.o_fifo_rd    (wdma_fifo_rd)
	);

	axi4_dma #(
		.AXI_ADDR_W  (AXI_ADDR_W),
		.SRAM_ADDR_W (SRAM_ADDR_W)
	 ) u_dma (
		.clk         (clk),
		.rstn        (resetn_synced),
		.i_src_addr  (csr_src_addr),
		.i_len       (csr_len[LEN_W-1:0]), // 1-128 safe accesss (>128 wraps wrptr)
		.i_start     (dma_start),
		.o_busy      (dma_busy),
		.o_done      (dma_done),
		.o_err       (dma_err),
		.o_m_arid    (o_m_axi_arid),
		.o_m_araddr  (o_m_axi_araddr),
		.o_m_arlen   (o_m_axi_arlen),
		.o_m_arsize  (o_m_axi_arsize),
		.o_m_arburst (o_m_axi_arburst),
		.o_m_arlock  (o_m_axi_arlock),
		.o_m_arcache (o_m_axi_arcache),
		.o_m_arprot  (o_m_axi_arprot),
		.o_m_arvalid (o_m_axi_arvalid),
		.i_m_arready (i_m_axi_arready),
		.i_m_rdata   (i_m_axi_rdata),
		.i_m_rresp   (i_m_axi_rresp),
		.i_m_rlast   (i_m_axi_rlast),
		.i_m_rvalid  (i_m_axi_rvalid),
		.o_m_rready  (o_m_axi_rready),
		.o_dma_cs    (dma_cs),
		.o_dma_we    (dma_we),
		.o_dma_mask  (dma_mask),
		.o_dma_addr  (dma_addr),
		.o_dma_wdata (dma_wdata),
		.o_swap      (dma_swap), // ownership
		.o_fill_done (dma_fill_done),
		.i_array_done(array_release)
	);

	pp_buf_sram u_sram (
		`ifdef USE_POWER_PINS
		.vdd			(vdd),
		.vss			(vss),
		`endif
		.clk            (clk),
		.rstn           (resetn_synced),
		.i_swap         (dma_swap),
		.o_ping_pong_sel(ping_pong_sel),
		.i_dma_cs       (dma_cs),
		.i_dma_we       (dma_we),
		.i_dma_mask     (dma_mask),
		.i_dma_addr     (dma_addr),
		.i_dma_wdata    (dma_wdata),
		.i_cs_array     (arr_ctrl_cs_p1),
		.i_addr_array   (arr_ctrl_addr),
		.o_array_rdata  (sram_rdata)
	);

	array_control #(
		.MATRIX_SIZE (MATRIX_SIZE),
		.DATA_WIDTH  (DATA_WIDTH),
		.SRAM_ADDR_W (SRAM_ADDR_W)
	) u_arr_ctrl (
		.clk           (clk),
		.rstn          (resetn_synced),
		.i_enable      (csr_ctrl[CTRL_EN]),
		.i_load_w      (csr_ctrl[CTRL_LOAD_W]),
		.i_room        (fifo_room), // no room for run stay idle
		.i_fill_done   (dma_fill_done),
		.o_array_done  (array_release),
		.o_cs_array    (arr_ctrl_cs_p1),
		.o_addr_array  (arr_ctrl_addr),
		.i_array_rdata (sram_rdata),
		.o_start       (arr_ctrl_start),
		.o_b_en        (arr_ctrl_b_en),
		.o_b_lane      (arr_ctrl_b_lane),
		.o_b_wdata     (arr_ctrl_b_wdata),
		.o_a_valid     (arr_ctrl_a_valid),
		.o_ld_a        (arr_ctrl_ld_a),
		.i_sys_done    (array_done),
		.o_busy        (arr_ctrl_busy),
		.o_w_valid     (arr_ctrl_w_valid)
	);

	systolic_array #(
		.MATRIX_SIZE (MATRIX_SIZE),
		.DATA_WIDTH  (DATA_WIDTH)
	) u_array (
		.clk            (clk),
		.rstn           (resetn_synced),
		.i_start        (arr_ctrl_start),
		.i_a_valid      (arr_ctrl_a_valid),
		.i_ld_a         (arr_ctrl_ld_a),
		.i_b_en         (arr_ctrl_b_en),
		.i_b_lane       (arr_ctrl_b_lane),
		.i_b_wdata      (arr_ctrl_b_wdata),
		.o_result_data  (arr_result_data),
		.o_result_valid (arr_result_valid),
		.o_done         (array_done),
		.o_busy         (array_busy)
	);

	res_cap_fifo #(
		.MATRIX_SIZE (MATRIX_SIZE),
		.DATA_WIDTH  (DATA_WIDTH)
	) u_res_fifo (
		.clk            (clk),
		.rstn           (resetn_synced),
		.i_result_valid (arr_result_valid),
		.i_result_data  (arr_result_data),
		.o_room         (fifo_room),
		.rd_en          (fifo_rd),
		.o_rdata        (fifo_rdata),
		.o_valid        (fifo_valid),
		.o_level        (fifo_level),
		.o_overflow     (fifo_overflow)
	);

endmodule
`default_nettype wire
