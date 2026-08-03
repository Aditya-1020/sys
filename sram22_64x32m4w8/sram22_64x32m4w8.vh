// blackbox view of the sram22 hard macro.

module sram22_64x32m4w8 (
`ifdef USE_POWER_PINS
	inout vdd,
	inout vss,
`endif
	input  wire        clk,
	input  wire        rstb,
	input  wire        ce,
	input  wire        we,
	input  wire [3:0]  wmask,
	input  wire [5:0]  addr,
	input  wire [31:0] din,
	output wire [31:0] dout
);
endmodule
