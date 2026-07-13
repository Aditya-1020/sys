`timescale 1ns/1ps

module tb_systolic_array;
    localparam MATRIX_SIZE = 2;
    localparam DATA_WIDTH = 8;
    localparam CSR_ADDR_W = 8;
    localparam STREAM_W = 32;

    localparam logic [CSR_ADDR_W-1:0] ADDR_CTRL = 'h00;
    localparam logic [CSR_ADDR_W-1:0] ADDR_STATUS = 'h04;
    localparam logic [CSR_ADDR_W-1:0] ADDR_CYCLES = 'h08;
    localparam CTRL_SIGNED_BIT = 1;

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rstn;
    logic csr_wr, csr_rd;
    logic [CSR_ADDR_W-1:0] csr_addr;
    logic [31:0] csr_wdata, csr_rdata;
    logic csr_rvalid;
    logic s_tvalid, s_tready, s_tlast;
    logic [STREAM_W-1:0] s_tdata;
    logic m_tvalid, m_tready, m_tlast;
    logic [STREAM_W-1:0] m_tdata;

`ifdef GLS
    systolic_array dut (
`else
    systolic_array #(
        .MATRIX_SIZE     (MATRIX_SIZE),
        .DATA_WIDTH      (DATA_WIDTH),
        .CSR_ADDR_W      (CSR_ADDR_W),
        .STREAM_W        (STREAM_W),
        .PERF_COUNTER_EN (1'b1)
    ) dut (
`endif
        .clk       (clk),
        .rstn      (rstn),
        .csr_wr    (csr_wr),
        .csr_rd    (csr_rd),
        .csr_addr  (csr_addr),
        .csr_wdata (csr_wdata),
        .csr_rdata (csr_rdata),
        .csr_rvalid(csr_rvalid),
        .s_tvalid  (s_tvalid),
        .s_tready  (s_tready),
        .s_tdata   (s_tdata),
        .s_tlast   (s_tlast),
        .m_tvalid  (m_tvalid),
        .m_tready  (m_tready),
        .m_tdata   (m_tdata),
        .m_tlast   (m_tlast)
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

    // stream drivers
    task automatic push(input logic [31:0] d, input logic last);
        s_tvalid <= 1'b1;
        s_tdata <= d;
        s_tlast <= last;
        @(posedge clk iff s_tready);
        s_tvalid <= 1'b0;
        s_tlast <= 1'b0;
    endtask

    task automatic pop(output logic [31:0] d, output logic last);
        @(posedge clk iff m_tvalid);
        d = m_tdata;
        last = m_tlast;
    endtask

    task automatic csr_read(input logic [CSR_ADDR_W-1:0] a, output logic [31:0] d);
        @(posedge clk);
        csr_addr <= a;
        csr_rd <= 1'b1;
        @(posedge clk);
        csr_rd <= 1'b0;
        @(posedge clk);
        d = csr_rdata;
    endtask

    matrix_t A = '{'{1, 2}, '{3, 4}};
    matrix_t B = '{'{5, 6}, '{7, 8}};
    matrix_t C_exp;
    
    logic [31:0] got, rdv;
    logic last;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_systolic_array);

        rstn = 0;
        csr_wr = 0;
        csr_rd = 0;
        csr_addr = 0;
        csr_wdata = 0;
        s_tvalid = 0;
        s_tdata = 0;
        s_tlast = 0;
        m_tready = 1; // always accept results
        
        repeat (4) @(posedge clk);
        
        rstn = 1;
        
        repeat (2) @(posedge clk);

        csr_read(ADDR_STATUS, rdv);
        check("STATUS idle", rdv, 32'h0);

        push(pack_bus(A), 1'b0);
        push(pack_bus(B), 1'b1);

        C_exp = matmul(A, B);
        
        for (int i = 0; i < MATRIX_SIZE*MATRIX_SIZE; i++) begin
            pop(got, last);
            check($sformatf("C%0d%0d", i/MATRIX_SIZE, i%MATRIX_SIZE),
                  got, C_exp[i/MATRIX_SIZE][i%MATRIX_SIZE]);
            if (last !== (i == MATRIX_SIZE*MATRIX_SIZE-1)) begin
                fail++; $display("FAIL tlast wrong at beat %0d (last=%0b)", i, last);
            end
        end

        // idle after draining
        repeat (2) @(posedge clk);
        csr_read(ADDR_STATUS, rdv);
        check("STATUS after drain", rdv, 32'h0);

`ifndef GLS
        dut.gen_perf_counters.perf_inst.report();
`endif
        $display("RESULT: %0d passed, %0d failed", pass, fail);
        $finish;
    end

endmodule
