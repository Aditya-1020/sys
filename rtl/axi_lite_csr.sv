`default_nettype none
`timescale 1ps/1ps

module axi_lite_csr #(
	parameter integer ADDR_WIDTH = 8,
	parameter integer DATA_WIDTH = 32,

	localparam integer CTRL_W = 6,  // EN, GO, LOAD_W, STORE, AUTO_ST, AUTO_FILL
	localparam integer LEN_W = 7,   // 1 to 64 words
	localparam integer NJOBS_W = 16 // auto-fill tile count
)(
	input wire aclk,
	// SYNCASYNCNET is expected: handshake/valid state below keeps async reset,
	// config and rdata registers use sync reset to keep them off the reset
	// leaf's RESET_B fanout. Safe because aresetn arrives via reset_gen's
	// synchronizer + leaf chain, so it is always held for several aclk edges.
	/* verilator lint_off SYNCASYNCNET */
	input wire aresetn,
	/* verilator lint_on SYNCASYNCNET */

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
	localparam integer ADDR_LSB = $clog2(DATA_WIDTH)-3;
	localparam integer IDX_W = ADDR_WIDTH - ADDR_LSB;
	localparam integer NREG = 7; // 0x00 to 0x18

	localparam integer IDX_CTRL = 0; // 0x00 RW
	localparam integer IDX_STATUS = 1;// 0x04 RO
	localparam integer IDX_SRC_ADDR = 2;  // 0x08 RW
	localparam integer IDX_LEN = 3; // 0x0C RW
	localparam integer IDX_RESULT = 4; // 0x10 RO, pop-on-read
	localparam integer IDX_DST_ADDR = 5;  // 0x14 RW
	localparam integer IDX_NJOBS = 6; // 0x18 RW

	logic awskd_valid, arskd_valid;
	wire wskd_valid;
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

	function automatic logic [NREG-1:0] reg_onehot (input logic [IDX_W-1:0] idx);
		reg_onehot = '0;
		for (int i = 0; i < NREG; i++) begin
			if (idx == IDX_W'(i)) begin
				reg_onehot[i] = 1'b1;
			end
		end
	endfunction

	wire [NREG-1:0] awdec = reg_onehot(i_s_axil_awaddr[ADDR_WIDTH-1:ADDR_LSB]);
	wire [NREG-1:0] ardec = reg_onehot(i_s_axil_araddr[ADDR_WIDTH-1:ADDR_LSB]);
	logic [NREG-1:0] awskd_sel, arskd_sel;

	skid_buffer #(
		.N(NREG)
	) aw_skid (
		.clk    (aclk),
		.rstn   (aresetn),
		.i_valid(i_s_axil_awvalid),
		.o_ready(o_s_axil_awready),
		.i_ready(axil_wr_ready),
		.o_valid(awskd_valid),
		.i_data (awdec),
		.o_data (awskd_sel)
	);

	logic w_full_r;
	logic [DATA_WIDTH-1:0] w_data_r;
	logic [(DATA_WIDTH/8)-1:0] w_strb_r;

	always_ff @(posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			w_full_r <= 1'b0;
		end else if (!w_full_r) begin
			w_full_r <= i_s_axil_wvalid;
		end else if (axil_wr_ready) begin
			w_full_r <= 1'b0;
		end
	end

	always_ff @(posedge aclk) begin
		if (!w_full_r && i_s_axil_wvalid) begin
			w_data_r <= i_s_axil_wdata;
			w_strb_r <= i_s_axil_wstrb;
		end
	end

	assign wskd_valid = w_full_r;
	assign wskd_data = w_data_r;
	assign wskd_strb = w_strb_r;
	assign o_s_axil_wready = !w_full_r;

	skid_buffer #(
		.N(NREG)
	) ar_skid (
		.clk    (aclk),
		.rstn   (aresetn),
		.i_valid(i_s_axil_arvalid),
		.o_ready(o_s_axil_arready),
		.i_ready(axil_rd_ready),
		.o_valid(arskd_valid),
		.i_data (ardec),
		.o_data (arskd_sel)
	);

	logic res_pop_r;
	wire ar_is_result = arskd_sel[IDX_RESULT];
	wire rd_ch_free = !axil_rvalid_r || i_s_axil_rready;
	wire res_rd_ok = i_fifo_valid && !res_pop_r;

	assign axil_wr_ready = awskd_valid && wskd_valid && (!axil_bvalid_r || i_s_axil_bready);
	assign axil_rd_ready = arskd_valid && rd_ch_free && (!ar_is_result || res_rd_ok);

	always_ff @(posedge aclk or negedge aresetn) begin
		if (!aresetn) begin
			res_pop_r <= 1'b0;
		end else begin
			res_pop_r <= axil_rd_ready && ar_is_result;
		end
	end

	assign csr_result_rd = res_pop_r;

	assign wskd_ctrl = apply_wstrb(csr_ctrl, wskd_data, wskd_strb);
	assign wskd_src_addr = apply_wstrb(csr_src_addr, wskd_data, wskd_strb);
	assign wskd_len = apply_wstrb(csr_len, wskd_data, wskd_strb);
	assign wskd_dst_addr = apply_wstrb(csr_dst_addr, wskd_data, wskd_strb);
	assign wskd_njobs = apply_wstrb(csr_njobs, wskd_data, wskd_strb);

	wire [NREG-1:0] wr_en = {NREG{axil_wr_ready}} & awskd_sel;

	logic [CTRL_W-1:0] csr_ctrl_r;
	logic [LEN_W-1:0] csr_len_r;
	logic [NJOBS_W-1:0] csr_njobs_r;

	assign csr_ctrl = DATA_WIDTH'(csr_ctrl_r);
	assign csr_len = DATA_WIDTH'(csr_len_r);
	assign csr_njobs = DATA_WIDTH'(csr_njobs_r);

	always_ff @(posedge aclk) begin
		if (!aresetn) begin
			csr_ctrl_r <= '0;
			csr_src_addr <= '0;
			csr_len_r <= '0;
			csr_dst_addr <= '0;
			csr_njobs_r <= '0;
		end else begin
			if (wr_en[IDX_CTRL]) csr_ctrl_r <= CTRL_W'(wskd_ctrl);
			if (wr_en[IDX_SRC_ADDR]) csr_src_addr <= wskd_src_addr;
			if (wr_en[IDX_LEN]) csr_len_r <= LEN_W'(wskd_len);
			if (wr_en[IDX_DST_ADDR]) csr_dst_addr <= wskd_dst_addr;
			if (wr_en[IDX_NJOBS]) csr_njobs_r <= NJOBS_W'(wskd_njobs);
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

	logic [DATA_WIDTH-1:0] rd_map [0:NREG-1];
	always_comb begin
		rd_map[IDX_CTRL] = csr_ctrl;
		rd_map[IDX_STATUS] = csr_status;
		rd_map[IDX_SRC_ADDR] = csr_src_addr;
		rd_map[IDX_LEN] = csr_len;
		rd_map[IDX_RESULT] = csr_result;
		rd_map[IDX_DST_ADDR] = csr_dst_addr;
		rd_map[IDX_NJOBS] = csr_njobs;
	end

	logic [DATA_WIDTH-1:0] axil_rdata_next;
	always_comb begin
		axil_rdata_next = '0;
		for (int i = 0; i < NREG; i++) begin
			axil_rdata_next |= {DATA_WIDTH{arskd_sel[i]}} & rd_map[i];
		end
	end

	always_ff @(posedge aclk) begin
		if (!aresetn) begin
			axil_rdata_r <= '0;
		end else if (axil_rd_ready) begin
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
