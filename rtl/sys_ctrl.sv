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
	
	logic go_q, store_q, auto_st_q, auto_fill_q;
	logic go_r, store_r, auto_st_r, auto_fill_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			go_q <= 1'b0;
			store_q <= 1'b0;
			auto_st_q <= 1'b0;
			auto_fill_q <= 1'b0;
			go_r <= 1'b0;
			store_r <= 1'b0;
			auto_st_r <= 1'b0;
			auto_fill_r <= 1'b0;
		end else begin
			go_q <= csr_ctrl[CTRL_GO];
			store_q <= csr_ctrl[CTRL_STORE];
			auto_st_q <= csr_ctrl[CTRL_AUTO_ST];
			auto_fill_q <= csr_ctrl[CTRL_AUTO_FILL];
			go_r <= go_q;
			store_r <= store_q;
			auto_st_r <= auto_st_q;
			auto_fill_r <= auto_fill_q;
		end
	end

	wire dma_start_manual = go_q && !go_r;
	wire wdma_start_manual = store_q && !store_r;
	wire auto_st_en = auto_st_q;
	wire auto_st_arm = auto_st_en && !auto_st_r;
	wire auto_fill_en = auto_fill_q;
	wire auto_fill_arm = auto_fill_en && !auto_fill_r;

	logic [31:0] dst_ptr_r;

	localparam int TB_W = $clog2(TILE_BYTES + 1);

	wire [TB_W:0]    dst_lo_sum = {1'b0, dst_ptr_r[TB_W-1:0]} + {1'b0, TB_W'(TILE_BYTES)};
	wire [31-TB_W:0] dst_hi_inc = dst_ptr_r[31:TB_W] + 1'b1;
	(* keep *) wire [31:0] dst_ptr_next =
		{(dst_lo_sum[TB_W] ? dst_hi_inc : dst_ptr_r[31:TB_W]), dst_lo_sum[TB_W-1:0]};

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			dst_ptr_r <= '0;
		end else if (auto_st_arm || wdma_start_manual) begin
			dst_ptr_r <= csr_dst_addr;
		end else if (aw_fire && auto_st_en) begin
			dst_ptr_r <= dst_ptr_next;
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

	logic fill_nz_r;
	wire auto_fill_pend = auto_fill_en && fill_nz_r;
	wire auto_fill_go = auto_fill_pend && !dma_busy;

	localparam int STRIDE_W = LEN_W + 2;

	wire [STRIDE_W-1:0] fill_stride = {csr_len[LEN_W-1:0], 2'b00};
	wire [STRIDE_W:0] src_lo_sum  = {1'b0, src_ptr_r[STRIDE_W-1:0]} + {1'b0, fill_stride};
	wire [31-STRIDE_W:0] src_hi_inc  = src_ptr_r[31:STRIDE_W] + 1'b1;
	(* keep *) wire [31:0] src_ptr_next = {(src_lo_sum[STRIDE_W] ? src_hi_inc : src_ptr_r[31:STRIDE_W]), src_lo_sum[STRIDE_W-1:0]};

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			src_ptr_r <= '0;
			fill_left_r <= '0;
			fill_nz_r <= 1'b0;
		end else begin
			if (auto_fill_arm) begin
				src_ptr_r <= csr_src_addr;
			end else if (dma_start_manual) begin
				src_ptr_r <= csr_src_addr;
			end else if (ar_fire && auto_fill_en) begin
				src_ptr_r <= src_ptr_next;
			end

			if (auto_fill_arm) begin
				fill_left_r <= csr_njobs[NJOB_W-1:0];
				fill_nz_r   <= (csr_njobs[NJOB_W-1:0] != '0);
			end
			else if (auto_fill_go) begin
				fill_left_r <= fill_left_r - 1'b1;
				fill_nz_r <= (fill_left_r == NJOB_W'(1)) ? 1'b0 : 1'b1;
			end
		end
	end

	wire tile_ready = (fifo_level >= LEVEL_W'(MATRIX_SIZE));

	assign o_dma_start  = dma_start_manual || auto_fill_go;
	assign o_dma_src = src_ptr_r;
	assign o_wdma_start = wdma_start_manual || (auto_st_en && tile_ready && (!wdma_busy || wdma_last_beat));
	assign o_wdma_dst = dst_ptr_r;

	logic [31:0] csr_status_next;
	always_comb begin
		csr_status_next = '0;
		csr_status_next[ST_DMA_BUSY] = dma_busy;
		csr_status_next[ST_DMA_DONE] = dma_done;
		csr_status_next[ST_DMA_ERR] = dma_err;
		csr_status_next[ST_FILL_DONE] = dma_fill_done;
		csr_status_next[ST_CTRL_BUSY] = arr_ctrl_busy;
		csr_status_next[ST_ARRAY_BUSY] = array_busy;
		csr_status_next[ST_ARRAY_DONE] = array_done;
		csr_status_next[ST_PP_SEL] = ping_pong_sel;
		csr_status_next[ST_W_VALID] = arr_ctrl_w_valid;
		csr_status_next[ST_RES_VALID] = fifo_valid;
		csr_status_next[ST_RES_OVF] = fifo_overflow;
		csr_status_next[ST_WDMA_BUSY] = wdma_busy;
		csr_status_next[ST_WDMA_DONE] = wdma_done;
		csr_status_next[ST_WDMA_ERR] = wdma_err;
		csr_status_next[ST_AF_BUSY] = auto_fill_pend;
		csr_status_next[ST_LEVEL_LSB +: LEVEL_W] = fifo_level;
		csr_status_next[ST_TILE_LSB +: 4] = tile_cnt_r;
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			o_csr_status <= '0;
		end else begin
			o_csr_status <= csr_status_next;
		end
	end

endmodule
`default_nettype wire
