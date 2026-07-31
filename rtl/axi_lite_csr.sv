`default_nettype none
`timescale 1ps/1ps

module axi_lite_csr #(
	parameter int ADDR_WIDTH = 8,
	parameter int DATA_WIDTH = 32
)(
	input wire aclk,
	input wire aresetn, // async reset sync deassert (HANDLE THIS IN TOP)

	// write addr channel
	input wire [ADDR_WIDTH-1:0] i_s_axil_awaddr,
	input wire i_s_axil_awvalid,
	output logic o_s_axil_awready,

	// write data channel
	input wire [DATA_WIDTH-1:0] i_s_axil_wdata,
	input wire [DATA_WIDTH/8-1:0] i_s_axil_wstrb,
	input wire i_s_axil_wvalid,
	output logic o_s_axil_wready,

	// wire response channel
	output logic [1:0] o_s_axil_bresp,
	output logic o_s_axil_bvalid,
	input wire i_s_axil_bready,

	// read addr channel
	input wire [ADDR_WIDTH-1:0] i_s_axil_araddr,
	input wire i_s_axil_arvalid,
	output logic o_s_axil_arready,

	// read data channel
	output logic [DATA_WIDTH-1:0] o_s_axil_rdata,
	output logic [1:0] o_s_axil_rresp,
	output logic o_s_axil_rvalid,
	input wire i_s_axil_rready,

	// csr interface
	input wire [DATA_WIDTH-1:0] csr_status, // status from 0x04
	output logic [DATA_WIDTH-1:0] csr_ctrl, // en/go
	output logic [DATA_WIDTH-1:0] csr_src_addr,
	output logic [DATA_WIDTH-1:0] csr_len 
);
	localparam int ADDR_LSB = $clog2(DATA_WIDTH)-3;
	localparam int IDX_W = ADDR_WIDTH - ADDR_LSB;

	localparam logic [IDX_W-1:0] IDX_CTRL = 0; // 0x00 RW
	localparam logic [IDX_W-1:0] IDX_STATUS = 1;// 0x04 RO
	localparam logic [IDX_W-1:0] IDX_SRC_ADDR = 2;  // 0x08 RW
	localparam logic [IDX_W-1:0] IDX_LEN = 3; // 0x0C RW

	logic awskd_valid, wskd_valid, arskd_valid;
	logic [IDX_W-1:0] awskd_addr, arskd_addr;
	logic [DATA_WIDTH-1:0] wskd_data, wskd_ctrl;
	logic [DATA_WIDTH-1:0] wskd_src_addr, wskd_len;
	logic [(DATA_WIDTH/8)-1:0] wskd_strb;
	logic axil_wr_ready, axil_rd_ready;

	logic axil_bvalid_r, axil_rvalid_r;
	logic [DATA_WIDTH-1:0] axil_rdata_r;

	function automatic logic [DATA_WIDTH-1:0] apply_wstrb (
		input logic [DATA_WIDTH-1:0] prev_data,
		input logic [DATA_WIDTH-1:0] data,
		input logic [(DATA_WIDTH/8)-1:0] wstrb
	);
		for (int k = 0; k < DATA_WIDTH/8; k++) begin
			apply_wstrb[k*8 +: 8] = wstrb[k] ? data[k*8 +: 8] : prev_data[k*8+:8];
		end
	endfunction

	skid_buffer #(
		.N(IDX_W)
	) aw_skid (
		.clk    (aclk),
		.rstn   (aresetn),
		.i_valid(i_s_axil_awvalid),
		.o_ready(o_s_axil_awready),
		.i_ready(axil_wr_ready),
		.o_valid(awskd_valid),
		.i_data (i_s_axil_awaddr[ADDR_WIDTH-1:ADDR_LSB]),
		.o_data (awskd_addr)
	);

	skid_buffer #(
		.N(DATA_WIDTH+(DATA_WIDTH/8))
	) w_skid (
		.clk    (aclk),
		.rstn   (aresetn),
		.i_valid(i_s_axil_wvalid),
		.o_ready(o_s_axil_wready),
		.i_ready(axil_wr_ready),
		.o_valid(wskd_valid),
		.i_data ({i_s_axil_wdata, i_s_axil_wstrb}),
		.o_data ({wskd_data, wskd_strb})
	);

	skid_buffer #(
		.N(IDX_W)
	) ar_skid (
		.clk    (aclk),
		.rstn   (aresetn),
		.i_valid(i_s_axil_arvalid),
		.o_ready(o_s_axil_arready),
		.i_ready(axil_rd_ready),
		.o_valid(arskd_valid),
		.i_data (i_s_axil_araddr[ADDR_WIDTH-1:ADDR_LSB]),
		.o_data (arskd_addr)
	);

	assign axil_wr_ready = awskd_valid && wskd_valid && (!axil_bvalid_r || i_s_axil_bready);
	assign axil_rd_ready = arskd_valid && (!axil_rvalid_r || i_s_axil_rready);

	assign wskd_ctrl = apply_wstrb(csr_ctrl, wskd_data, wskd_strb);
	assign wskd_src_addr = apply_wstrb(csr_src_addr, wskd_data, wskd_strb);
	assign wskd_len = apply_wstrb(csr_len, wskd_data, wskd_strb);

	logic wr_ctrl, wr_src_addr, wr_len;
	always_comb begin
		wr_ctrl = 1'b0;
		wr_src_addr = 1'b0;
		wr_len = 1'b0;
		
		unique case (awskd_addr)
			IDX_CTRL: wr_ctrl = axil_wr_ready;
			IDX_SRC_ADDR: wr_src_addr = axil_wr_ready;
			IDX_LEN: wr_len = axil_wr_ready;
		endcase
	end

	always_ff @(posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			csr_ctrl <= '0;
			csr_src_addr <= '0;
			csr_len <= '0;
		end else if (axil_wr_ready) begin
			if (wr_ctrl) csr_ctrl <= wskd_ctrl;
			if (wr_src_addr) csr_src_addr <= wskd_src_addr;
			if (wr_len) csr_len <= wskd_len;
		end
	end

	always_ff @(posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			axil_bvalid_r <= 1'b0;
		end else if (axil_wr_ready) begin
			axil_bvalid_r <= 1'b1;
		end else if (i_s_axil_bready) begin
			axil_bvalid_r <= 1'b0;
		end
	end

	assign o_s_axil_bvalid = axil_bvalid_r;
	assign o_s_axil_bresp = 2'b00;

	logic [31:0] axil_rdata_next;
	always_comb begin
		axil_rdata_next = '0;
		unique case (arskd_addr)
			IDX_CTRL: axil_rdata_next = csr_ctrl;
			IDX_STATUS: axil_rdata_next = csr_status;
			IDX_SRC_ADDR: axil_rdata_next = csr_src_addr;
			IDX_LEN: axil_rdata_next = csr_len;
		endcase
	end

	always_ff @(posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			axil_rdata_r <= '0;
		end else if (!axil_rvalid_r || i_s_axil_rready) begin
			axil_rdata_r <= axil_rdata_next;
		end
	end

	always_ff @(posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			axil_rvalid_r <= 1'b0;
		end else if (axil_rd_ready) begin
			axil_rvalid_r <= 1'b1;
		end else if (i_s_axil_rready) begin
			axil_rvalid_r <= 1'b0;
		end
	end

	assign o_s_axil_rvalid = axil_rvalid_r;
	assign o_s_axil_rdata = axil_rdata_r;
	assign o_s_axil_rresp = 2'b00;

endmodule
`default_nettype wire
