`default_nettype none
`timescale 1ps/1ps

module csr #(
	parameter integer DATA_W = 32,
	parameter integer ADDR_W = 8,
	parameter integer MATRIX_SIZE = 4,
	parameter integer WEIGHT_DW = 8,
	parameter integer LANE_W = $clog2(MATRIX_SIZE),
	parameter integer ROW_W = MATRIX_SIZE*WEIGHT_DW // 32
)(
	input wire clk,
	input wire rstn,
	input wire i_en,
	input wire i_wr_en,
	input wire [ADDR_W-1:0] i_addr,
	input wire [DATA_W-1:0] i_wdata,
	output logic [DATA_W-1:0] o_rdata,

	output logic o_b_en,
	output logic [LANE_W-1:0] o_b_lane,
	output logic [ROW_W-1:0] o_b_wdata,

	// ctlr
	output logic o_enable,
	output logic o_sign_en,
	// status
	input wire i_busy,
	input wire i_empty,
	input wire i_full,
	input wire i_done,
	input wire [7:0] i_level,
	
	input wire i_jobdone, //  pulse on finished job
	output logic o_irq
);
	// word addresses (i_addr[7:2]) b stores words 4-7
	localparam logic [5:0] ADDR_CTRL = 6'd0;
	localparam logic [5:0] ADDR_STATUS = 6'd1;
	localparam logic [5:0] ADDR_IRQ= 6'd2;

	localparam integer CTRL_EN = 0;
	localparam integer CTRL_SIGN_EN = 1;
	localparam integer CTRL_IRQ_EN = 2;

	logic [5:0] word;
	logic wr, rd, ctrl_wr;
	logic b_wr, irq_clear;

	assign word = i_addr[7:2];
	assign wr = i_en && i_wr_en;
	assign rd = i_en && ~i_wr_en;
	assign ctrl_wr = wr && (word == ADDR_CTRL);
	assign b_wr = wr && (word[5:2] == 4'd1);
	assign irq_clear = wr && (word == ADDR_IRQ) && i_wdata[0];

	// ctrl[0] en, ctrl[1] sign, ctrl[2]] irq en
	logic [2:0] ctrl_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			ctrl_r <= '0;
		end else if (ctrl_wr) begin
			ctrl_r <= i_wdata[2:0];
		end
	end
		
	logic irq_r, next_irq;
	always_comb begin
		next_irq = irq_r;
		if (irq_clear) begin
			next_irq = 1'b0;
		end
		if (i_jobdone) begin // sticky
			next_irq = 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			irq_r <= 1'b0;
		end else begin
			irq_r <= next_irq;
		end
	end

	// read
	logic [DATA_W-1:0] status_w;
	assign status_w = {16'h0, i_level, 4'h0, i_done, i_full, i_empty, i_busy};
	logic [DATA_W-1:0] rdata_r, next_rdata;
	
	always_comb begin
		next_rdata ='0;
		if (word == ADDR_CTRL) begin
			next_rdata = {29'h0, ctrl_r};
		end else if (word == ADDR_STATUS) begin
			next_rdata = status_w;
		end else if (word == ADDR_IRQ) begin
			next_rdata = {31'h0, irq_r};
		end else begin
			next_rdata = '0;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rdata_r <= '0;
		end else if (rd) begin
			rdata_r <= next_rdata;
		end
	end
	
	assign o_rdata = rdata_r;
	assign o_enable = ctrl_r[CTRL_EN];
	assign o_sign_en = ctrl_r[CTRL_SIGN_EN];
	assign o_irq = irq_r && ctrl_r[CTRL_IRQ_EN];
	assign o_b_en = b_wr && !i_busy;
	assign o_b_lane = word[1:0];
	assign o_b_wdata = i_wdata[ROW_W-1:0];

endmodule
`default_nettype wire
