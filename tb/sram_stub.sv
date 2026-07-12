// sim-only replacement for sram

`timescale 1ps/1ps

module sram_model #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  wire clk,

    input  wire rw_csb,
    input  wire rw_web,
    input  wire [ADDR_WIDTH-1:0] rw_addr,
    input  wire [DATA_WIDTH-1:0] rw_din,
    output reg  [DATA_WIDTH-1:0] rw_dout,

    input  wire r_csb,
    input  wire [ADDR_WIDTH-1:0] r_addr,
    output reg  [DATA_WIDTH-1:0] r_dout
);
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (!rw_csb) begin
            if (!rw_web) mem[rw_addr] <= rw_din;
            else rw_dout <= mem[rw_addr];
        end
    end

    always @(posedge clk) begin
        if (!r_csb) r_dout <= mem[r_addr];
    end

endmodule
