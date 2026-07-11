`timescale 1ps/1ps

interface csr_if #(
    parameter ADDR_W = 8
)(
    input logic clk
);
    logic rstn, wr;
    logic [ADDR_W-1:0] addr;
    logic [31:0] wdata, rdata;
 
    clocking cb @(posedge clk);
        default input #1step output #0;
        output wr, addr, wdata;
        input rdata;
    endclocking
 
    task automatic write(input logic [ADDR_W-1:0] a, input logic [31:0] data);
        cb.addr <= a;
        cb.wdata <= data;
        cb.wr <= 1'b1;
        @(cb);
        cb.wr <= 1'b0;
    endtask
 
    task automatic read(input logic [ADDR_W-1:0] a, output logic [31:0] data);
        cb.addr <= a;
        cb.wr <= 1'b0;
        @(cb);
        data = cb.rdata;
    endtask
endinterface


module tb_systolic_array;
    localparam MATRIX_SIZE = 2;
    localparam DATA_WIDTH = 8;
    localparam CSR_ADDR_W = 8;
 
    localparam logic [CSR_ADDR_W-1:0] ADDR_CTRL = 'h00;
    localparam logic [CSR_ADDR_W-1:0] ADDR_STATUS = 'h04;
    localparam logic [CSR_ADDR_W-1:0] ADDR_CYCLES = 'h08;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RES_0 = 'h0C;
    localparam logic [CSR_ADDR_W-1:0] ADDR_MATRIX_A = 'h10;
    localparam logic [CSR_ADDR_W-1:0] ADDR_MATRIX_B = 'h14;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RES_1 = 'h18;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RES_2 = 'h1C;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RESULT_00 = 'h20;
    
    localparam CTRL_START_BIT = 0;
    localparam CTRL_SIGNED_BIT = 1;
    localparam CTRL_ABORT_BIT = 2;
 
    localparam STATUS_BUSY_BIT = 0;
    localparam STATUS_DONE_BIT = 1;
    localparam STATUS_STATE_LSB = 2;
 
    // mirrored state for field checks
    localparam logic [2:0] ST_IDLE = 3'd0;
    localparam logic [2:0] ST_CLEAR = 3'd1;
    localparam logic [2:0] ST_COMPUTE = 3'd2;
    localparam logic [2:0] ST_DRAIN = 3'd3;
    localparam logic [2:0] ST_DONE = 3'd4;

    localparam EXPECT_CYCLES = 8; // CLAER + COMPUTE + DRAIN (1+6+1)
    localparam TIMEOUT_CYCLES = 50;


    logic clk;
    initial clk = 1'd0;
    always #10 clk = ~clk;

    csr_if #(.ADDR_W(CSR_ADDR_W)) bus (.clk(clk));

    systolic_array #(
        .MATRIX_SIZE(MATRIX_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .CSR_ADDR_W (CSR_ADDR_W)
    ) dut (
        .clk      (clk),
        .rstn     (bus.rstn),
        .csr_wr   (bus.wr),
        .csr_addr (bus.addr),
        .csr_wdata(bus.wdata),
        .csr_rdata(bus.rdata)
    );

    int pass = 0;
    int fail = 0;

    
endmodule
