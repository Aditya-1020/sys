`default_nettype none
`timescale 1ps/1ps

module axi_lite_csr #(
	parameter int ADDR_WIDTH = 8,
	parameter int DATA_WIDTH = 32,

	// only the implemented bits of these registers are stored; the rest read back 0
	parameter int CTRL_W = 6,  // EN, GO, LOAD_W, STORE, AUTO_ST, AUTO_FILL
	parameter int LEN_W = 7,   // 1..64 words
	parameter int NJOBS_W = 16 // auto-fill tile count
)(
	input wire aclk,
	input wire aresetn,

	// write addr channel. byte address into a word-aligned register file, so both
	// address ports drop [1:0] -- see ADDR_LSB below
	/* verilator lint_off UNUSEDSIGNAL */
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
	/* verilator lint_on UNUSEDSIGNAL */
	input wire i_s_axil_arvalid,
	output logic o_s_axil_arready,

	// read data channel
	output logic [DATA_WIDTH-1:0] o_s_axil_rdata,
	output logic [1:0] o_s_axil_rresp,
	output logic o_s_axil_rvalid,
	input wire i_s_axil_rready,
	input wire i_fifo_valid,

	// csr interface
	input wire [DATA_WIDTH-1:0] csr_status, // status from 0x04
	output wire [DATA_WIDTH-1:0] csr_ctrl, // en/go
	output logic [DATA_WIDTH-1:0] csr_src_addr,// dma byte addr
	output wire [DATA_WIDTH-1:0] csr_len, // dma word cnt
	output logic [DATA_WIDTH-1:0] csr_dst_addr,// result store byte addr
	output wire [DATA_WIDTH-1:0] csr_njobs, // auto-fill tiles for self-launch

	input wire [DATA_WIDTH-1:0] csr_result,
	output wire csr_result_rd
);
	localparam int ADDR_LSB = $clog2(DATA_WIDTH)-3;
	localparam int IDX_W = ADDR_WIDTH - ADDR_LSB;

	localparam logic [IDX_W-1:0] IDX_CTRL = 0; // 0x00 RW
	localparam logic [IDX_W-1:0] IDX_STATUS = 1;// 0x04 RO
	localparam logic [IDX_W-1:0] IDX_SRC_ADDR = 2;  // 0x08 RW
	localparam logic [IDX_W-1:0] IDX_LEN = 3; // 0x0C RW
	localparam logic [IDX_W-1:0] IDX_RESULT = 4; // 0x10 RO, pop-on-read
	localparam logic [IDX_W-1:0] IDX_DST_ADDR = 5;  // 0x14 RW
	localparam logic [IDX_W-1:0] IDX_NJOBS = 6; // 0x18 RW

	logic awskd_valid, arskd_valid;
	wire wskd_valid;
	logic [IDX_W-1:0] awskd_addr, arskd_addr;
	wire [DATA_WIDTH-1:0] wskd_data;
	/* verilator lint_off UNUSEDSIGNAL */
	logic [DATA_WIDTH-1:0] wskd_ctrl;
	logic [DATA_WIDTH-1:0] wskd_src_addr, wskd_len, wskd_dst_addr, wskd_njobs;
	/* verilator lint_on UNUSEDSIGNAL */
	wire [(DATA_WIDTH/8)-1:0] wskd_strb;
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

	assign wskd_valid = i_s_axil_wvalid;
	assign wskd_data = i_s_axil_wdata;
	assign wskd_strb = i_s_axil_wstrb;
	assign o_s_axil_wready = axil_wr_ready;

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
	
	wire stall_result_rd = arskd_valid && (arskd_addr == IDX_RESULT) && !i_fifo_valid;
	assign axil_wr_ready = awskd_valid && wskd_valid && (!axil_bvalid_r || i_s_axil_bready);
	assign axil_rd_ready = arskd_valid && (!axil_rvalid_r || i_s_axil_rready) && !stall_result_rd;

	assign wskd_ctrl = apply_wstrb(csr_ctrl, wskd_data, wskd_strb);
	assign wskd_src_addr = apply_wstrb(csr_src_addr, wskd_data, wskd_strb);
	assign wskd_len = apply_wstrb(csr_len, wskd_data, wskd_strb);
	assign wskd_dst_addr = apply_wstrb(csr_dst_addr, wskd_data, wskd_strb);
	assign wskd_njobs = apply_wstrb(csr_njobs, wskd_data, wskd_strb);

	logic wr_ctrl, wr_src_addr, wr_len, wr_dst_addr, wr_njobs;
	always_comb begin
		wr_ctrl = 1'b0;
		wr_src_addr = 1'b0;
		wr_len = 1'b0;
		wr_dst_addr = 1'b0;
		wr_njobs = 1'b0;

		case (awskd_addr)
			IDX_CTRL: wr_ctrl = axil_wr_ready;
			IDX_SRC_ADDR: wr_src_addr = axil_wr_ready;
			IDX_LEN: wr_len = axil_wr_ready;
			IDX_DST_ADDR: wr_dst_addr = axil_wr_ready;
			IDX_NJOBS: wr_njobs = axil_wr_ready;
			default: ;
		endcase
	end

	logic [CTRL_W-1:0] csr_ctrl_r;
	logic [LEN_W-1:0] csr_len_r;
	logic [NJOBS_W-1:0] csr_njobs_r;

	assign csr_ctrl = DATA_WIDTH'(csr_ctrl_r);
	assign csr_len = DATA_WIDTH'(csr_len_r);
	assign csr_njobs = DATA_WIDTH'(csr_njobs_r);

	always_ff @(posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			csr_ctrl_r <= '0;
			csr_src_addr <= '0;
			csr_len_r <= '0;
			csr_dst_addr <= '0;
			csr_njobs_r <= '0;
		end else if (axil_wr_ready) begin
			if (wr_ctrl) csr_ctrl_r <= CTRL_W'(wskd_ctrl);
			if (wr_src_addr) csr_src_addr <= wskd_src_addr;
			if (wr_len) csr_len_r <= LEN_W'(wskd_len);
			if (wr_dst_addr) csr_dst_addr <= wskd_dst_addr;
			if (wr_njobs) csr_njobs_r <= NJOBS_W'(wskd_njobs);
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
		case (arskd_addr)
			IDX_CTRL: axil_rdata_next = csr_ctrl;
			IDX_STATUS: axil_rdata_next = csr_status;
			IDX_SRC_ADDR: axil_rdata_next = csr_src_addr;
			IDX_LEN: axil_rdata_next = csr_len;
			IDX_RESULT: axil_rdata_next = csr_result;
			IDX_DST_ADDR: axil_rdata_next = csr_dst_addr;
			IDX_NJOBS: axil_rdata_next = csr_njobs;
			default: ;
		endcase
	end
	
	assign csr_result_rd = axil_rd_ready && (arskd_addr == IDX_RESULT);

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
