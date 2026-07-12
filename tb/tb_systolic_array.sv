`timescale 1ps/1ps

interface csr_if #(
    parameter ADDR_W = 8
)(
    input logic clk
);
    logic rstn, wr, rd, rvalid;
    logic [ADDR_W-1:0] addr;
    logic [31:0] wdata, rdata;

    task automatic write(input logic [ADDR_W-1:0] a, input logic [31:0] d);
        @(posedge clk);
        addr <= a;
        wdata <= d;
        wr <= 1'b1;
        @(posedge clk);
        wr <= 1'b0;
    endtask

    // rdata valid one cycle after rd strobe
    task automatic read(input logic [ADDR_W-1:0] a, output logic [31:0] d);
        @(posedge clk);
        addr <= a;
        rd <= 1'b1;
        @(posedge clk);
        rd <= 1'b0;
        @(posedge clk);
        d = rdata;
    endtask
endinterface


module tb_systolic_array;
    localparam MATRIX_SIZE = 2;
    localparam DATA_WIDTH = 8;
    localparam CSR_ADDR_W = 8;

    localparam logic [CSR_ADDR_W-1:0] ADDR_CTRL = 'h00;
    localparam logic [CSR_ADDR_W-1:0] ADDR_STATUS ='h04;
    localparam logic [CSR_ADDR_W-1:0] ADDR_CYCLES = 'h08;
    localparam logic [CSR_ADDR_W-1:0] ADDR_A0 = 'h40;
    localparam logic [CSR_ADDR_W-1:0] ADDR_B0 = 'h80;
    localparam logic [CSR_ADDR_W-1:0] ADDR_C00 = 'hC0;

    localparam CTRL_START_BIT= 0;
    localparam CTRL_SIGNED_BIT = 1;
    localparam CTRL_ABORT_BIT = 2;

    localparam STATUS_BUSY_BIT = 0;
    localparam STATUS_DONE_BIT = 1;

    localparam EXPECT_CYCLES = 13; // 2 load + 1 clear + 6 compute + 4 writeback
    localparam TIMEOUT_POLLS = 50;

    logic clk = 1'b0;
    always #10 clk = ~clk;

    csr_if #(.ADDR_W(CSR_ADDR_W)) bus (.clk(clk));

    systolic_array #(
        .MATRIX_SIZE     (MATRIX_SIZE),
        .DATA_WIDTH      (DATA_WIDTH),
        .CSR_ADDR_W      (CSR_ADDR_W),
        .PERF_COUNTER_EN (1'b1)
    ) dut (
        .clk       (clk),
        .rstn      (bus.rstn),
        .csr_wr    (bus.wr),
        .csr_rd    (bus.rd),
        .csr_addr  (bus.addr),
        .csr_wdata (bus.wdata),
        .csr_rdata (bus.rdata),
        .csr_rvalid(bus.rvalid)
    );

    int pass = 0;
    int fail = 0;

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got === exp) begin
            pass++;
            $display("PASS %s 0x%08h", name, got);
        end else begin
            fail++;
            $display("FAIL %s got 0x%08h expected 0x%08h", name, got, exp);
        end
    endtask

    // matrices as plain integer packed
    typedef int matrix_t [MATRIX_SIZE][MATRIX_SIZE];

    function automatic logic [31:0] pack_bus(input matrix_t m);
        pack_bus = '0;
        for (int r = 0; r < MATRIX_SIZE; r++)
            for (int c = 0; c < MATRIX_SIZE; c++)
                pack_bus[DATA_WIDTH*(MATRIX_SIZE*r + c) +: DATA_WIDTH] = DATA_WIDTH'(m[r][c]);
    endfunction

    function automatic matrix_t matmul(input matrix_t x, input matrix_t y);
        matmul = '{default: 0};
        for (int r = 0; r < MATRIX_SIZE; r++) begin
            for (int c = 0; c < MATRIX_SIZE; c++) begin
                for (int k = 0; k < MATRIX_SIZE; k++) begin
                    matmul[r][c] += x[r][k] * y[k][c];
                end
            end
        end
    endfunction

    matrix_t A = '{'{1, 2}, '{3, 4}};
    matrix_t B = '{'{5, 6}, '{7, 8}};
    matrix_t C_exp;

    logic [31:0] rd_val;
    int polls;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_systolic_array);

        bus.rstn = 1'b0;
        bus.wr = 1'b0;
        bus.rd = 1'b0;
        bus.addr = '0;
        bus.wdata = '0;
        repeat (4) @(posedge clk);
        bus.rstn = 1'b1;
        repeat (2) @(posedge clk);

        bus.read(ADDR_STATUS, rd_val);
        check("STATUS idle", rd_val, 32'h0);

        // cache write and readback
        bus.write(ADDR_A0, pack_bus(A));
        bus.write(ADDR_B0, pack_bus(B));
        bus.read(ADDR_A0, rd_val);
        check("A readback", rd_val, pack_bus(A));
        bus.read(ADDR_B0, rd_val);
        check("B readback", rd_val, pack_bus(B));

        // unsigned run
        bus.write(ADDR_CTRL, 32'h1 << CTRL_START_BIT);
        polls = 0;
        do begin
            bus.read(ADDR_STATUS, rd_val);
            polls++;
        end while (!rd_val[STATUS_DONE_BIT] && polls < TIMEOUT_POLLS);
        check("DONE set", 32'(rd_val[STATUS_DONE_BIT]), 32'h1);

        bus.read(ADDR_CYCLES, rd_val);
        check("CYCLES", rd_val, EXPECT_CYCLES);

        C_exp = matmul(A, B);
        
        for (int i = 0; i < MATRIX_SIZE*MATRIX_SIZE; i++) begin
            bus.read(ADDR_C00 + 8'(4*i), rd_val);
            check($sformatf("C%0d%0d", i/MATRIX_SIZE, i%MATRIX_SIZE), rd_val, C_exp[i/MATRIX_SIZE][i%MATRIX_SIZE]);
        end

        // ack done (w1c)
        bus.write(ADDR_STATUS, 32'h1 << STATUS_DONE_BIT);
        bus.read(ADDR_STATUS, rd_val);
        check("DONE cleared", rd_val, 32'h0);

        dut.gen_perf_counters.perf_inst.report();

        $display("RESULT: %0d passed, %0d failed", pass, fail);
        $finish;
    end

endmodule
