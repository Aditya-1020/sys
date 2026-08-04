`timescale 1ps/1ps
`default_nettype none
module axi_lite_csr (
	aclk,
	aresetn,
	i_s_axil_awaddr,
	i_s_axil_awvalid,
	o_s_axil_awready,
	i_s_axil_wdata,
	i_s_axil_wstrb,
	i_s_axil_wvalid,
	o_s_axil_wready,
	o_s_axil_bresp,
	o_s_axil_bvalid,
	i_s_axil_bready,
	i_s_axil_araddr,
	i_s_axil_arvalid,
	o_s_axil_arready,
	o_s_axil_rdata,
	o_s_axil_rresp,
	o_s_axil_rvalid,
	i_s_axil_rready,
	i_fifo_valid,
	csr_status,
	csr_ctrl,
	csr_src_addr,
	csr_len,
	csr_dst_addr,
	csr_result,
	csr_result_rd
);
	reg _sv2v_0;
	parameter signed [31:0] ADDR_WIDTH = 8;
	parameter signed [31:0] DATA_WIDTH = 32;
	input wire aclk;
	input wire aresetn;
	input wire [ADDR_WIDTH - 1:0] i_s_axil_awaddr;
	input wire i_s_axil_awvalid;
	output wire o_s_axil_awready;
	input wire [DATA_WIDTH - 1:0] i_s_axil_wdata;
	input wire [(DATA_WIDTH / 8) - 1:0] i_s_axil_wstrb;
	input wire i_s_axil_wvalid;
	output wire o_s_axil_wready;
	output wire [1:0] o_s_axil_bresp;
	output wire o_s_axil_bvalid;
	input wire i_s_axil_bready;
	input wire [ADDR_WIDTH - 1:0] i_s_axil_araddr;
	input wire i_s_axil_arvalid;
	output wire o_s_axil_arready;
	output wire [DATA_WIDTH - 1:0] o_s_axil_rdata;
	output wire [1:0] o_s_axil_rresp;
	output wire o_s_axil_rvalid;
	input wire i_s_axil_rready;
	input wire i_fifo_valid;
	input wire [DATA_WIDTH - 1:0] csr_status;
	output reg [DATA_WIDTH - 1:0] csr_ctrl;
	output reg [DATA_WIDTH - 1:0] csr_src_addr;
	output reg [DATA_WIDTH - 1:0] csr_len;
	output reg [DATA_WIDTH - 1:0] csr_dst_addr;
	input wire [DATA_WIDTH - 1:0] csr_result;
	output wire csr_result_rd;
	localparam signed [31:0] ADDR_LSB = $clog2(DATA_WIDTH) - 3;
	localparam signed [31:0] IDX_W = ADDR_WIDTH - ADDR_LSB;
	localparam [IDX_W - 1:0] IDX_CTRL = 0;
	localparam [IDX_W - 1:0] IDX_STATUS = 1;
	localparam [IDX_W - 1:0] IDX_SRC_ADDR = 2;
	localparam [IDX_W - 1:0] IDX_LEN = 3;
	localparam [IDX_W - 1:0] IDX_RESULT = 4;
	localparam [IDX_W - 1:0] IDX_DST_ADDR = 5;
	wire awskd_valid;
	wire wskd_valid;
	wire arskd_valid;
	wire [IDX_W - 1:0] awskd_addr;
	wire [IDX_W - 1:0] arskd_addr;
	wire [DATA_WIDTH - 1:0] wskd_data;
	wire [DATA_WIDTH - 1:0] wskd_ctrl;
	wire [DATA_WIDTH - 1:0] wskd_src_addr;
	wire [DATA_WIDTH - 1:0] wskd_len;
	wire [DATA_WIDTH - 1:0] wskd_dst_addr;
	wire [(DATA_WIDTH / 8) - 1:0] wskd_strb;
	wire axil_wr_ready;
	wire axil_rd_ready;
	reg axil_bvalid_r;
	reg axil_rvalid_r;
	reg [DATA_WIDTH - 1:0] axil_rdata_r;
	function automatic [DATA_WIDTH - 1:0] apply_wstrb;
		input reg [DATA_WIDTH - 1:0] prev_data;
		input reg [DATA_WIDTH - 1:0] data;
		input reg [(DATA_WIDTH / 8) - 1:0] wstrb;
		reg signed [31:0] k;
		for (k = 0; k < (DATA_WIDTH / 8); k = k + 1)
			apply_wstrb[k * 8+:8] = (wstrb[k] ? data[k * 8+:8] : prev_data[k * 8+:8]);
	endfunction
	skid_buffer #(.N(IDX_W)) aw_skid(
		.clk(aclk),
		.rstn(aresetn),
		.i_valid(i_s_axil_awvalid),
		.o_ready(o_s_axil_awready),
		.i_ready(axil_wr_ready),
		.o_valid(awskd_valid),
		.i_data(i_s_axil_awaddr[ADDR_WIDTH - 1:ADDR_LSB]),
		.o_data(awskd_addr)
	);
	skid_buffer #(.N(DATA_WIDTH + (DATA_WIDTH / 8))) w_skid(
		.clk(aclk),
		.rstn(aresetn),
		.i_valid(i_s_axil_wvalid),
		.o_ready(o_s_axil_wready),
		.i_ready(axil_wr_ready),
		.o_valid(wskd_valid),
		.i_data({i_s_axil_wdata, i_s_axil_wstrb}),
		.o_data({wskd_data, wskd_strb})
	);
	skid_buffer #(.N(IDX_W)) ar_skid(
		.clk(aclk),
		.rstn(aresetn),
		.i_valid(i_s_axil_arvalid),
		.o_ready(o_s_axil_arready),
		.i_ready(axil_rd_ready),
		.o_valid(arskd_valid),
		.i_data(i_s_axil_araddr[ADDR_WIDTH - 1:ADDR_LSB]),
		.o_data(arskd_addr)
	);
	wire stall_result_rd = (arskd_valid && (arskd_addr == IDX_RESULT)) && !i_fifo_valid;
	assign axil_wr_ready = (awskd_valid && wskd_valid) && (!axil_bvalid_r || i_s_axil_bready);
	assign axil_rd_ready = (arskd_valid && (!axil_rvalid_r || i_s_axil_rready)) && !stall_result_rd;
	assign wskd_ctrl = apply_wstrb(csr_ctrl, wskd_data, wskd_strb);
	assign wskd_src_addr = apply_wstrb(csr_src_addr, wskd_data, wskd_strb);
	assign wskd_len = apply_wstrb(csr_len, wskd_data, wskd_strb);
	assign wskd_dst_addr = apply_wstrb(csr_dst_addr, wskd_data, wskd_strb);
	reg wr_ctrl;
	reg wr_src_addr;
	reg wr_len;
	reg wr_dst_addr;
	always @(*) begin
		if (_sv2v_0)
			;
		wr_ctrl = 1'b0;
		wr_src_addr = 1'b0;
		wr_len = 1'b0;
		wr_dst_addr = 1'b0;
		case (awskd_addr)
			IDX_CTRL: wr_ctrl = axil_wr_ready;
			IDX_SRC_ADDR: wr_src_addr = axil_wr_ready;
			IDX_LEN: wr_len = axil_wr_ready;
			IDX_DST_ADDR: wr_dst_addr = axil_wr_ready;
			default:
				;
		endcase
	end
	always @(posedge aclk or negedge aresetn)
		if (!aresetn) begin
			csr_ctrl <= 1'sb0;
			csr_src_addr <= 1'sb0;
			csr_len <= 1'sb0;
			csr_dst_addr <= 1'sb0;
		end
		else if (axil_wr_ready) begin
			if (wr_ctrl)
				csr_ctrl <= wskd_ctrl;
			if (wr_src_addr)
				csr_src_addr <= wskd_src_addr;
			if (wr_len)
				csr_len <= wskd_len;
			if (wr_dst_addr)
				csr_dst_addr <= wskd_dst_addr;
		end
	always @(posedge aclk or negedge aresetn)
		if (!aresetn)
			axil_bvalid_r <= 1'b0;
		else if (axil_wr_ready)
			axil_bvalid_r <= 1'b1;
		else if (i_s_axil_bready)
			axil_bvalid_r <= 1'b0;
	assign o_s_axil_bvalid = axil_bvalid_r;
	assign o_s_axil_bresp = 2'b00;
	reg [31:0] axil_rdata_next;
	always @(*) begin
		if (_sv2v_0)
			;
		axil_rdata_next = 1'sb0;
		case (arskd_addr)
			IDX_CTRL: axil_rdata_next = csr_ctrl;
			IDX_STATUS: axil_rdata_next = csr_status;
			IDX_SRC_ADDR: axil_rdata_next = csr_src_addr;
			IDX_LEN: axil_rdata_next = csr_len;
			IDX_RESULT: axil_rdata_next = csr_result;
			IDX_DST_ADDR: axil_rdata_next = csr_dst_addr;
			default:
				;
		endcase
	end
	assign csr_result_rd = axil_rd_ready && (arskd_addr == IDX_RESULT);
	always @(posedge aclk or negedge aresetn)
		if (!aresetn)
			axil_rdata_r <= 1'sb0;
		else if (!axil_rvalid_r || i_s_axil_rready)
			axil_rdata_r <= axil_rdata_next;
	always @(posedge aclk or negedge aresetn)
		if (!aresetn)
			axil_rvalid_r <= 1'b0;
		else if (axil_rd_ready)
			axil_rvalid_r <= 1'b1;
		else if (i_s_axil_rready)
			axil_rvalid_r <= 1'b0;
	assign o_s_axil_rvalid = axil_rvalid_r;
	assign o_s_axil_rdata = axil_rdata_r;
	assign o_s_axil_rresp = 2'b00;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
