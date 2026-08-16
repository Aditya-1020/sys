`default_nettype none
`timescale 1ps/1ps

module sys_ctrl (
	input wire clk,
	input wire rstn,
	input wire [31:0] csr_ctrl,
	input wire [31:0] csr_src_addr,
	input wire [31:0] csr_len,
	input wire [31:0] csr_dst_addr,
	input wire [31:0] csr_njobs,
	input wire dma_busy,
	input wire dma_done,
	input wire dma_err,
	input wire dma_fill_done,
	input wire wdma_busy,
	input wire wdma_done,
	input wire wdma_err,
	input wire wdma_resp,
	input wire wdma_last_beat,
	input wire arr_ctrl_busy,
	input wire arr_ctrl_w_valid,
	input wire array_busy,
	input wire array_done,
	input wire ping_pong_sel,
	input wire fifo_valid,
	input wire fifo_overflow,
	input wire [sys_pkg::LEVEL_W-1:0] fifo_level, 
	input wire ar_fire,
	input wire aw_fire,
	output wire o_dma_start,
	output wire [31:0] o_dma_src,
	output wire o_wdma_start,
	output wire [31:0] o_wdma_dst,
	output logic [31:0] o_csr_status
);
	import sys_pkg::*;

	logic go_r, store_r, auto_st_r, auto_fill_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			go_r <= 1'b0;
			store_r <= 1'b0;
			auto_st_r <= 1'b0;
			auto_fill_r <= 1'b0;
		end else begin
			go_r <= csr_ctrl[CTRL_GO];
			store_r <= csr_ctrl[CTRL_STORE];
			auto_st_r <= csr_ctrl[CTRL_AUTO_ST];
			auto_fill_r <= csr_ctrl[CTRL_AUTO_FILL];
		end
	end

	wire dma_start_manual = csr_ctrl[CTRL_GO] && !go_r;
	wire wdma_start_manual = csr_ctrl[CTRL_STORE] && !store_r;
	wire auto_st_en = csr_ctrl[CTRL_AUTO_ST];
	wire auto_st_arm = auto_st_en && !auto_st_r;
	wire auto_fill_en = csr_ctrl[CTRL_AUTO_FILL];
	wire auto_fill_arm = auto_fill_en && !auto_fill_r;

	logic [31:0] dst_ptr_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			dst_ptr_r <= '0;
		end else if (auto_st_arm || wdma_start_manual) begin
			dst_ptr_r <= csr_dst_addr;
		end else if (aw_fire && auto_st_en) begin
			dst_ptr_r <= dst_ptr_r + 32'(TILE_BYTES);
		end
	end

	logic [3:0] tile_cnt_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			tile_cnt_r <= '0;
		end else if (auto_st_arm) begin
			tile_cnt_r <= '0;
		end else if (wdma_resp) begin
			tile_cnt_r <= tile_cnt_r + 1'b1;
		end
	end

	logic [31:0] src_ptr_r;
	logic [NJOB_W-1:0] fill_left_r;
	wire auto_fill_pend = auto_fill_en && (fill_left_r != '0);
	wire auto_fill_go = auto_fill_pend && !dma_busy;
	wire [31:0] fill_stride = {23'b0, csr_len[LEN_W-1:0], 2'b00};

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			src_ptr_r <= '0;
			fill_left_r <= '0;
		end else begin
			if (auto_fill_arm) begin
				src_ptr_r <= csr_src_addr;
			end else if (dma_start_manual) begin
				src_ptr_r <= csr_src_addr;
			end else if (ar_fire && auto_fill_en) begin
				src_ptr_r <= src_ptr_r + fill_stride;
			end

			if (auto_fill_arm) begin
				fill_left_r <= csr_njobs[NJOB_W-1:0];
			end
			else if (auto_fill_go) begin
				fill_left_r <= fill_left_r - 1'b1;
			end
		end
	end

	wire tile_ready = (fifo_level >= LEVEL_W'(MATRIX_SIZE));

	assign o_dma_start  = dma_start_manual || auto_fill_go;
	assign o_dma_src = src_ptr_r;
	assign o_wdma_start = wdma_start_manual || (auto_st_en && tile_ready && (!wdma_busy || wdma_last_beat));
	assign o_wdma_dst = dst_ptr_r;

	always_comb begin
		o_csr_status = '0;
		o_csr_status[ST_DMA_BUSY] = dma_busy;
		o_csr_status[ST_DMA_DONE] = dma_done;
		o_csr_status[ST_DMA_ERR] = dma_err;
		o_csr_status[ST_FILL_DONE] = dma_fill_done;
		o_csr_status[ST_CTRL_BUSY] = arr_ctrl_busy;
		o_csr_status[ST_ARRAY_BUSY] = array_busy;
		o_csr_status[ST_ARRAY_DONE] = array_done;
		o_csr_status[ST_PP_SEL] = ping_pong_sel;
		o_csr_status[ST_W_VALID] = arr_ctrl_w_valid;
		o_csr_status[ST_RES_VALID] = fifo_valid;
		o_csr_status[ST_RES_OVF] = fifo_overflow;
		o_csr_status[ST_WDMA_BUSY] = wdma_busy;
		o_csr_status[ST_WDMA_DONE] = wdma_done;
		o_csr_status[ST_WDMA_ERR] = wdma_err;
		o_csr_status[ST_AF_BUSY] = auto_fill_pend;
		o_csr_status[ST_LEVEL_LSB +: LEVEL_W] = fifo_level;
		o_csr_status[ST_TILE_LSB +: 4] = tile_cnt_r;
	end

endmodule
`default_nettype wire
