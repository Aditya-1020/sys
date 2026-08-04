`timescale 1ps/1ps
`default_nettype none
module axi4_dma_wr (
	clk,
	rstn,
	i_dst_addr,
	i_start,
	o_busy,
	o_done,
	o_err,
	o_m_awid,
	o_m_awaddr,
	o_m_awlen,
	o_m_awsize,
	o_m_awburst,
	o_m_awlock,
	o_m_awcache,
	o_m_awprot,
	o_m_awvalid,
	i_m_awready,
	o_m_wdata,
	o_m_wstrb,
	o_m_wlast,
	o_m_wvalid,
	i_m_wready,
	i_m_bresp,
	i_m_bvalid,
	o_m_bready,
	i_fifo_valid,
	i_fifo_rdata,
	o_fifo_rd
);
	reg _sv2v_0;
	parameter integer ROW_W = 32;
	parameter integer AXI_ADDR_W = 32;
	parameter integer AXI_ID_W = 4;
	parameter integer BEATS = 16;
	parameter integer AXI_DATA_W = ROW_W;
	localparam integer CNT_W = $clog2(BEATS);
	input wire clk;
	input wire rstn;
	input wire [AXI_ADDR_W - 1:0] i_dst_addr;
	input wire i_start;
	output wire o_busy;
	output wire o_done;
	output wire o_err;
	output wire [AXI_ID_W - 1:0] o_m_awid;
	output wire [AXI_ADDR_W - 1:0] o_m_awaddr;
	output wire [7:0] o_m_awlen;
	output wire [2:0] o_m_awsize;
	output wire [1:0] o_m_awburst;
	output wire o_m_awlock;
	output wire [3:0] o_m_awcache;
	output wire [2:0] o_m_awprot;
	output wire o_m_awvalid;
	input wire i_m_awready;
	output wire [AXI_DATA_W - 1:0] o_m_wdata;
	output wire [(AXI_DATA_W / 8) - 1:0] o_m_wstrb;
	output wire o_m_wlast;
	output wire o_m_wvalid;
	input wire i_m_wready;
	input wire [1:0] i_m_bresp;
	input wire i_m_bvalid;
	output wire o_m_bready;
	input wire i_fifo_valid;
	input wire [AXI_DATA_W - 1:0] i_fifo_rdata;
	output wire o_fifo_rd;
	reg [1:0] current_state;
	reg [1:0] next_state;
	wire idle_state = current_state == 2'd0;
	reg [CNT_W - 1:0] beat_cnt_r;
	reg [AXI_ADDR_W - 1:0] dst_addr_r;
	function automatic signed [CNT_W - 1:0] sv2v_cast_66408_signed;
		input reg signed [CNT_W - 1:0] inp;
		sv2v_cast_66408_signed = inp;
	endfunction
	wire last_cnt = beat_cnt_r == sv2v_cast_66408_signed(BEATS - 1);
	wire aw_valid_int;
	wire aw_ready_int;
	wire w_valid_int;
	wire w_ready_int;
	wire b_valid_int;
	wire b_ready_int;
	wire [(AXI_ID_W + AXI_ADDR_W) + 20:0] aw_data_int;
	wire [(AXI_ID_W + AXI_ADDR_W) + 20:0] aw_data_out;
	wire [(AXI_DATA_W + (AXI_DATA_W / 8)) + 0:0] w_data_int;
	wire [(AXI_DATA_W + (AXI_DATA_W / 8)) + 0:0] w_data_out;
	wire [1:0] b_data_int;
	wire [1:0] b_data_out;
	assign aw_data_int[AXI_ID_W + (AXI_ADDR_W + 20)-:((AXI_ID_W + (AXI_ADDR_W + 20)) >= (AXI_ADDR_W + 21) ? ((AXI_ID_W + (AXI_ADDR_W + 20)) - (AXI_ADDR_W + 21)) + 1 : ((AXI_ADDR_W + 21) - (AXI_ID_W + (AXI_ADDR_W + 20))) + 1)] = 1'sb0;
	assign aw_data_int[AXI_ADDR_W + 20-:((AXI_ADDR_W + 20) >= 21 ? AXI_ADDR_W + 0 : 22 - (AXI_ADDR_W + 20))] = {dst_addr_r[AXI_ADDR_W - 1:2], 2'b00};
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	assign aw_data_int[20-:8] = sv2v_cast_8_signed(BEATS - 1);
	assign aw_data_int[12-:3] = 3'b010;
	assign aw_data_int[9-:2] = 2'b01;
	assign aw_data_int[7] = 1'b0;
	assign aw_data_int[6-:4] = 4'b0011;
	assign aw_data_int[2-:3] = 3'b000;
	skid_buffer #(.N((((AXI_ID_W + AXI_ADDR_W) + 20) >= 0 ? (AXI_ID_W + AXI_ADDR_W) + 21 : 1 - ((AXI_ID_W + AXI_ADDR_W) + 20)))) skid_aw(
		.clk(clk),
		.rstn(rstn),
		.i_valid(aw_valid_int),
		.o_ready(aw_ready_int),
		.i_ready(i_m_awready),
		.o_valid(o_m_awvalid),
		.i_data(aw_data_int),
		.o_data(aw_data_out)
	);
	assign o_m_awid = aw_data_out[AXI_ID_W + (AXI_ADDR_W + 20)-:((AXI_ID_W + (AXI_ADDR_W + 20)) >= (AXI_ADDR_W + 21) ? ((AXI_ID_W + (AXI_ADDR_W + 20)) - (AXI_ADDR_W + 21)) + 1 : ((AXI_ADDR_W + 21) - (AXI_ID_W + (AXI_ADDR_W + 20))) + 1)];
	assign o_m_awaddr = aw_data_out[AXI_ADDR_W + 20-:((AXI_ADDR_W + 20) >= 21 ? AXI_ADDR_W + 0 : 22 - (AXI_ADDR_W + 20))];
	assign o_m_awlen = aw_data_out[20-:8];
	assign o_m_awsize = aw_data_out[12-:3];
	assign o_m_awburst = aw_data_out[9-:2];
	assign o_m_awlock = aw_data_out[7];
	assign o_m_awcache = aw_data_out[6-:4];
	assign o_m_awprot = aw_data_out[2-:3];
	assign w_data_int[AXI_DATA_W + ((AXI_DATA_W / 8) + 0)-:((AXI_DATA_W + ((AXI_DATA_W / 8) + 0)) >= ((AXI_DATA_W / 8) + 1) ? ((AXI_DATA_W + ((AXI_DATA_W / 8) + 0)) - ((AXI_DATA_W / 8) + 1)) + 1 : (((AXI_DATA_W / 8) + 1) - (AXI_DATA_W + ((AXI_DATA_W / 8) + 0))) + 1)] = i_fifo_rdata;
	assign w_data_int[(AXI_DATA_W / 8) + 0-:(((AXI_DATA_W / 8) + 0) >= 1 ? (AXI_DATA_W / 8) + 0 : 2 - ((AXI_DATA_W / 8) + 0))] = 1'sb1;
	assign w_data_int[0] = last_cnt;
	skid_buffer #(.N((((AXI_DATA_W + (AXI_DATA_W / 8)) + 0) >= 0 ? (AXI_DATA_W + (AXI_DATA_W / 8)) + 1 : 1 - ((AXI_DATA_W + (AXI_DATA_W / 8)) + 0)))) skid_w(
		.clk(clk),
		.rstn(rstn),
		.i_valid(w_valid_int),
		.o_ready(w_ready_int),
		.i_ready(i_m_wready),
		.o_valid(o_m_wvalid),
		.i_data(w_data_int),
		.o_data(w_data_out)
	);
	assign o_m_wdata = w_data_out[AXI_DATA_W + ((AXI_DATA_W / 8) + 0)-:((AXI_DATA_W + ((AXI_DATA_W / 8) + 0)) >= ((AXI_DATA_W / 8) + 1) ? ((AXI_DATA_W + ((AXI_DATA_W / 8) + 0)) - ((AXI_DATA_W / 8) + 1)) + 1 : (((AXI_DATA_W / 8) + 1) - (AXI_DATA_W + ((AXI_DATA_W / 8) + 0))) + 1)];
	assign o_m_wstrb = w_data_out[(AXI_DATA_W / 8) + 0-:(((AXI_DATA_W / 8) + 0) >= 1 ? (AXI_DATA_W / 8) + 0 : 2 - ((AXI_DATA_W / 8) + 0))];
	assign o_m_wlast = w_data_out[0];
	assign b_data_int[1-:2] = i_m_bresp;
	skid_buffer #(.N(2)) skid_b(
		.clk(clk),
		.rstn(rstn),
		.i_valid(i_m_bvalid),
		.o_ready(o_m_bready),
		.i_ready(b_ready_int),
		.o_valid(b_valid_int),
		.i_data(b_data_int),
		.o_data(b_data_out)
	);
	assign aw_valid_int = current_state == 2'd1;
	assign w_valid_int = (current_state == 2'd2) && i_fifo_valid;
	assign b_ready_int = current_state == 2'd3;
	wire beat = w_valid_int && w_ready_int;
	wire last_beat = beat && last_cnt;
	wire bresp_beat = (current_state == 2'd3) && b_valid_int;
	assign o_fifo_rd = beat;
	assign o_busy = !idle_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = current_state;
		(* full_case, parallel_case *)
		case (current_state)
			2'd0:
				if (i_start)
					next_state = 2'd1;
			2'd1:
				if (aw_ready_int)
					next_state = 2'd2;
			2'd2:
				if (last_beat)
					next_state = 2'd3;
			2'd3:
				if (bresp_beat)
					next_state = 2'd0;
		endcase
	end
	always @(posedge clk or negedge rstn)
		if (!rstn)
			current_state <= 2'd0;
		else
			current_state <= next_state;
	always @(posedge clk)
		if (idle_state && i_start)
			dst_addr_r <= i_dst_addr;
	always @(posedge clk)
		if (idle_state)
			beat_cnt_r <= 1'sb0;
		else if (beat)
			beat_cnt_r <= beat_cnt_r + 1'b1;
	reg done_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			done_r <= 1'b0;
		else if (idle_state && i_start)
			done_r <= 1'b0;
		else if (bresp_beat)
			done_r <= 1'b1;
	assign o_done = done_r;
	reg err_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			err_r <= 1'b0;
		else if (idle_state && i_start)
			err_r <= 1'b0;
		else if (bresp_beat && (b_data_out[1-:2] != 2'b00))
			err_r <= 1'b1;
	assign o_err = err_r;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
