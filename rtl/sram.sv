`default_nettype none
`timescale 1ps/1ps

module sram #(
	parameter integer DATA_WIDTH = 32,
	parameter integer ADDR_WIDTH = 9
)(
	input wire clk,
	// verilator lint_off UNUSEDSIGNAL
	input wire rstn,
	// verilator lint_on UNUSEDSIGNAL

	input wire i_p0_en, // active high
	input wire i_p0_we,
	input wire [3:0] i_p0_wrmask,
	input wire [ADDR_WIDTH-1:0] i_p0_addr,
	input wire [DATA_WIDTH-1:0] i_p0_wdata,
	output wire [DATA_WIDTH-1:0] o_p0_rdata,

	input wire i_p1_en,
	input wire [ADDR_WIDTH-1:0] i_p1_addr,
	output wire [DATA_WIDTH-1:0] o_p1_rdata // valid 1 cycle after enab;e
);
	// sram prams mirror
	localparam integer NUM_WMASKS = 4;
	// verilator lint_off UNUSEDPARAM
	localparam integer RAM_DEPTH = 1 << ADDR_WIDTH;	 // 512 words 
	// verilator lint_on UNUSEDPARAM
	
	wire csb0, web0, csb1;
	assign csb0 = ~i_p0_en; // low = selected
	assign csb1 = ~i_p1_en;
	assign web0 = ~i_p0_en; // low = wr

	wire [NUM_WMASKS-1:0] wmask0;
	//assign wmask0 = i_p0_wrmask && {NUM_WMASKS{i_p0_we}};
	assign wmask0 = i_p0_we ? i_p0_wrmask : '0;

	sky130_sram_2kbyte_1rw1r_32x512_8 sram_cell (
		// port 0: read/write
		.clk0(clk),
		.csb0(csb0),
		.web0(web0),
		.wmask0(wmask0),
		.addr0(i_p0_addr),
		.din0(i_p0_wdata),
		.dout0(o_p0_rdata),
		// port 1: read
		.clk1(clk),
		.csb1(csb1),
		.addr1(i_p1_addr),
		.dout1(o_p1_rdata)
	);

	// verilator lint_off UNUSEDSIGNAL
	wire _unused_ok = 1'b0 && &{1'b0, rstn, RAM_DEPTH,  1'b0};
	// verilator lint_on UNUSEDSIGNAL

endmodule
`default_nettype wire
