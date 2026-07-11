`default_nettype none
`timescale 1ps/1ps

// SRAM buffers two srams two read ports for a dn b
module sram_model #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    
    input wire rw_csb, // active low
    input wire rw_web, // active low (0=wr, 1=rd)
    input wire [ADDR_WIDTH-1:0] rw_addr,
    input wire [DATA_WIDTH-1:0] rw_din,
    output wire [DATA_WIDTH-1:0] rw_dout,

    input wire r_csb, // active low
    input wire [ADDR_WIDTH-1:0] r_addr,
    output wire [DATA_WIDTH-1:0] r_dout
);
    localparam logic [3:0] WR_MASK_FULL = 4'b1111;

    sky130_sram_1kbyte_1rw1r_32x256_8 sram (
        // port 0: read/write
        .clk0(clk),
        .csb0(rw_csb),
        .web0(rw_web),
        .wmask0(WR_MASK_FULL),
        .addr0(rw_addr),
        .din0(rw_din),
        .dout0(rw_dout),
        
        // port 1: read only
        .clk1(clk),
        .csb1(r_csb),
        .addr1(r_addr),
        .dout1(r_dout)
    );

endmodule
`default_nettype wire
