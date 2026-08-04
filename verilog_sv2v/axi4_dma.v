`timescale 1ps/1ps
`default_nettype none
module axi4_dma (
	clk,
	rstn,
	i_src_addr,
	i_len,
	i_start,
	o_busy,
	o_done,
	o_err,
	o_m_arid,
	o_m_araddr,
	o_m_arlen,
	o_m_arsize,
	o_m_arburst,
	o_m_arlock,
	o_m_arcache,
	o_m_arprot,
	o_m_arvalid,
	i_m_arready,
	i_m_rdata,
	i_m_rresp,
	i_m_rlast,
	i_m_rvalid,
	o_m_rready,
	o_dma_cs,
	o_dma_we,
	o_dma_mask,
	o_dma_addr,
	o_dma_wdata,
	o_swap,
	o_fill_done,
	i_array_done
);
	reg _sv2v_0;
	parameter integer ROW_W = 32;
	parameter integer AXI_ADDR_W = 32;
	parameter integer AXI_ID_W = 4;
	parameter integer SRAM_ADDR_W = 6;
	parameter integer AXI_DATA_W = ROW_W;
	parameter integer LEN_W = SRAM_ADDR_W + 1;
	input wire clk;
	input wire rstn;
	input wire [AXI_ADDR_W - 1:0] i_src_addr;
	input wire [LEN_W - 1:0] i_len;
	input wire i_start;
	output wire o_busy;
	output wire o_done;
	output wire o_err;
	output wire [AXI_ID_W - 1:0] o_m_arid;
	output wire [AXI_ADDR_W - 1:0] o_m_araddr;
	output wire [7:0] o_m_arlen;
	output wire [2:0] o_m_arsize;
	output wire [1:0] o_m_arburst;
	output wire o_m_arlock;
	output wire [3:0] o_m_arcache;
	output wire [2:0] o_m_arprot;
	output wire o_m_arvalid;
	input wire i_m_arready;
	input wire [AXI_DATA_W - 1:0] i_m_rdata;
	input wire [1:0] i_m_rresp;
	input wire i_m_rlast;
	input wire i_m_rvalid;
	output wire o_m_rready;
	output wire o_dma_cs;
	output wire o_dma_we;
	output wire [3:0] o_dma_mask;
	output wire [SRAM_ADDR_W - 1:0] o_dma_addr;
	output wire [ROW_W - 1:0] o_dma_wdata;
	output wire o_swap;
	output wire o_fill_done;
	input wire i_array_done;
	assign o_m_arid = 1'sb0;
	assign o_m_arsize = 3'b010;
	assign o_m_arburst = 2'b01;
	assign o_m_arlock = 1'b0;
	assign o_m_arcache = 4'b0011;
	assign o_m_arprot = 3'b000;
	assign o_dma_we = 1'b1;
	assign o_dma_mask = 4'hf;
	assign o_dma_wdata = i_m_rdata;
	reg [1:0] current_state;
	reg [1:0] next_state;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			current_state <= 2'd0;
		else
			current_state <= next_state;
	wire idle_state = current_state == 2'd0;
	assign o_m_arvalid = current_state == 2'd1;
	assign o_m_rready = current_state == 2'd2;
	assign o_dma_cs = i_m_rvalid && o_m_rready;
	wire beat = o_dma_cs;
	wire last_beat = beat && i_m_rlast;
	function automatic [10:0] sv2v_cast_11;
		input reg [10:0] inp;
		sv2v_cast_11 = inp;
	endfunction
	wire [10:0] burst_end_w = {1'b0, i_src_addr[11:2]} + sv2v_cast_11(i_len);
	function automatic signed [LEN_W - 1:0] sv2v_cast_B3885_signed;
		input reg signed [LEN_W - 1:0] inp;
		sv2v_cast_B3885_signed = inp;
	endfunction
	wire desc_bad = ((i_len == {LEN_W {1'sb0}}) || (i_len > sv2v_cast_B3885_signed(1 << SRAM_ADDR_W))) || (burst_end_w > 11'd1024);
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = current_state;
		(* full_case, parallel_case *)
		case (current_state)
			2'd0:
				if (i_start && !desc_bad)
					next_state = 2'd1;
			2'd1:
				if (i_m_arready)
					next_state = 2'd2;
			2'd2:
				if (last_beat)
					next_state = 2'd3;
			2'd3:
				if (i_array_done)
					next_state = 2'd0;
		endcase
	end
	reg [AXI_ADDR_W - 1:0] src_addr_r;
	reg [LEN_W - 1:0] len_r;
	always @(posedge clk)
		if (idle_state && i_start) begin
			src_addr_r <= i_src_addr;
			len_r <= i_len;
		end
	assign o_m_araddr = {src_addr_r[AXI_ADDR_W - 1:2], 2'b00};
	assign o_m_arlen = len_r - 1'b1;
	reg [SRAM_ADDR_W - 1:0] wr_ptr_r;
	assign o_dma_addr = wr_ptr_r;
	always @(posedge clk)
		if (idle_state && i_start)
			wr_ptr_r <= 1'sb0;
		else if (beat)
			wr_ptr_r <= wr_ptr_r + 1'b1;
	wire expected_last = {1'b0, wr_ptr_r} == (len_r - 1'b1);
	wire len_mismatch = beat && (i_m_rlast != expected_last);
	assign o_busy = !idle_state;
	reg done_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			done_r <= 1'b0;
		else if (idle_state && i_start)
			done_r <= 1'b0;
		else if (last_beat)
			done_r <= 1'b1;
	assign o_done = done_r;
	reg err_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			err_r <= 1'b0;
		else if ((idle_state && i_start) && desc_bad)
			err_r <= 1'b1;
		else if (idle_state && i_start)
			err_r <= 1'b0;
		else if ((beat && (i_m_rresp != 2'b00)) || len_mismatch)
			err_r <= 1'b1;
	assign o_err = err_r;
	assign o_fill_done = current_state == 2'd3;
	assign o_swap = (current_state == 2'd3) && i_array_done;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
