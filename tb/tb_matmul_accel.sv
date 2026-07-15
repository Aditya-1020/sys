`timescale 1ps/1ps

module tb_matmul_accel;
    localparam int unsigned AW = 8;// csr address width
    localparam int unsigned DW = 32; // csr data width
    localparam int unsigned N = 4;
    localparam int unsigned EW = 8;
    localparam int unsigned RW = (2*EW) + $clog2(N);
    localparam int unsigned CASES = 6;

    localparam int unsigned JOB_CYCLES = 3*N + 2;
    localparam int UNS_MAX = (1 << EW) - 1;
    localparam int SGN_MAX = (1 << (EW-1)) - 1;
    localparam int SGN_MIN = -(1 << (EW-1));

    localparam logic [AW-1:0] ADDR_CTRL = 'h00;
    localparam logic [AW-1:0] ADDR_STATUS = 'h04;
    localparam logic [AW-1:0] ADDR_CYCLES = 'h08;
    localparam logic [AW-1:0] ADDR_IRQ = 'h0C;
    localparam logic [AW-1:0] ADDR_A_BASE = 'h10;
    localparam logic [AW-1:0] ADDR_B_BASE = 'h20;
    localparam logic [AW-1:0] ADDR_C_BASE = 'h40;
    localparam logic [AW-1:0] ADDR_UNMAPPED = 'h30;
    localparam int CTRL_START_BIT = 0;
    localparam int CTRL_SIGNED_BIT = 1;
    localparam int CTRL_IRQ_EN_BIT = 2;
    localparam int STATUS_BUSY_BIT = 0;
    localparam int STATUS_DONE_BIT = 1;
    localparam int IRQ_DONE_BIT = 0;

    logic rstn;
    logic csr_wr, csr_rd;
    logic [AW-1:0] csr_addr;
    logic [DW-1:0] csr_wdata, csr_rdata;
    logic csr_rvalid, o_irq;

    logic clk = 1'b0;
    always #5 clk = ~clk;

`ifdef GLS
    matmul_accel dut (
`else
    matmul_accel #(
        .CSR_ADDR_W (AW),
        .CSR_DATA_W (DW)
    ) dut (
`endif
        .clk        (clk),
        .rstn       (rstn),
        .csr_wr     (csr_wr),
        .csr_rd     (csr_rd),
        .csr_addr   (csr_addr),
        .csr_wdata  (csr_wdata),
        .csr_rdata  (csr_rdata),
        .csr_rvalid (csr_rvalid),
        .o_irq      (o_irq)
    );

    int A [N][N], B [N][N], C [N][N];
    int pass, fail;
    bit sign;
    int t;

    task automatic check(input string name, input int got, input int exp);
        if (got === exp) begin
            pass++;
            $display("PASS %s got %0d", name, got);
        end else begin
            fail++;
            $display("FAIL %s got %0d expected %0d", name, got, exp);
        end
    endtask

    task automatic dut_reset;
        rstn <= 1'b0;
        csr_wr <= 1'b0;
        csr_rd <= 1'b0;
        csr_addr <= '0;
        csr_wdata <= '0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rstn <= 1'b1;
        repeat (2) @(posedge clk);
    endtask

    task automatic write_csr(input logic [AW-1:0] addr, input logic [DW-1:0] data);
        @(posedge clk);
        csr_addr <= addr;
        csr_wdata <= data;
        csr_wr <= 1'b1;
        @(posedge clk);
        csr_wr <= 1'b0;
        csr_addr <= '0;
        csr_wdata <= '0;
    endtask

    // returns mid cycle so combinational outputs can be sampled right after
    task automatic read_csr(input logic [AW-1:0] addr, output logic [DW-1:0] data);
        @(posedge clk);
        csr_addr <= addr;
        csr_rd <= 1'b1;
        @(posedge clk);
        csr_rd <= 1'b0;
        csr_addr <= '0;
        @(negedge clk);

        if (!csr_rvalid) begin
            fail++;
            $display("FAIL rvalid not asserted one cycle after rd, addr %02h", addr);
        end
        data = csr_rdata;
    endtask

    task automatic csr_test;
        logic [DW-1:0] rd;

        read_csr(ADDR_CTRL, rd);
        check("csr ctrl reset", rd, '0);
        read_csr(ADDR_STATUS, rd);
        check("csr status reset", rd, '0);
        read_csr(ADDR_CYCLES, rd);
        check("csr cycles reset", rd, '0);
        read_csr(ADDR_IRQ, rd);
        check("csr irq reset", rd, '0);
        check("csr irq line reset", o_irq, 1'b0);

        write_csr(ADDR_CTRL, (1 << CTRL_SIGNED_BIT) | (1 << CTRL_IRQ_EN_BIT));
        read_csr(ADDR_CTRL, rd);
        check("csr ctrl signed", rd[CTRL_SIGNED_BIT], 1'b1);
        check("csr ctrl irq_en", rd[CTRL_IRQ_EN_BIT], 1'b1);
        check("csr ctrl start reads 0", rd[CTRL_START_BIT], 1'b0);

        check("csr irq line no done", o_irq, 1'b0);

        write_csr(ADDR_CTRL, '0);
        read_csr(ADDR_CTRL, rd);
        check("csr ctrl cleared", rd, '0);

        read_csr(ADDR_UNMAPPED, rd);
        check("csr unmapped reads 0", rd, '0);
    endtask

    task automatic gen_matrices;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                case (t)
                    0: begin
                        A[i][j] = i*N + j + 1;
                        B[i][j] = (i == j);
                    end
                    1: begin
                        A[i][j] = UNS_MAX;
                        B[i][j] = UNS_MAX;
                    end
                    3: begin
                        A[i][j] = ((i+j) % 2) ? SGN_MAX : SGN_MIN;
                        B[i][j] = ((i+j) % 2) ? SGN_MAX : SGN_MIN;
                    end
                    default: begin
                        A[i][j] = $urandom_range(0, UNS_MAX) + (sign ? SGN_MIN : 0);
                        B[i][j] = $urandom_range(0, UNS_MAX) + (sign ? SGN_MIN : 0);
                    end
                endcase
            end
        end
    endtask

    task automatic matmul;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                C[i][j] = 0;
                for (int k = 0; k < N; k++) begin
                    C[i][j] += A[i][k] * B[k][j];
                end
            end
        end
    endtask

    task automatic load_matrices;
        logic [DW-1:0] word_a, word_b;
        for (int i = 0; i < N; i++) begin
            word_a = '0;
            word_b = '0;
            for (int j = 0; j < N; j++) begin
                word_a[EW*j +: EW] = A[i][j][EW-1:0];
                word_b[EW*j +: EW] = B[i][j][EW-1:0];
            end
            write_csr(ADDR_A_BASE + AW'(4*i), word_a);
            write_csr(ADDR_B_BASE + AW'(4*i), word_b);
        end
    endtask

    task automatic run_job;
        logic [DW-1:0] ctrl, rd;
        int polls;

        ctrl = '0;
        ctrl[CTRL_START_BIT] = 1'b1;
        ctrl[CTRL_SIGNED_BIT] = sign;
        ctrl[CTRL_IRQ_EN_BIT] = 1'b1;
        write_csr(ADDR_CTRL, ctrl);

        read_csr(ADDR_STATUS, rd);
        check($sformatf("t%0d busy after start", t), rd[STATUS_BUSY_BIT], 1'b1);

        polls = 0;
        do begin
            read_csr(ADDR_STATUS, rd);
            polls++;
        end while (!rd[STATUS_DONE_BIT] && (polls < 64));

        check($sformatf("t%0d done", t), rd[STATUS_DONE_BIT], 1'b1);
        check($sformatf("t%0d idle after done", t), rd[STATUS_BUSY_BIT], 1'b0);
        check($sformatf("t%0d irq raised", t), o_irq, 1'b1);

        read_csr(ADDR_CYCLES, rd);
        check($sformatf("t%0d cycles", t), rd, JOB_CYCLES);
    endtask

    task automatic read_result;
        logic [DW-1:0] rd;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                read_csr(ADDR_C_BASE + AW'(4*(N*i + j)), rd);
                check($sformatf("t%0d C[%0d][%0d]", t, i, j), sign ? int'($signed(rd)) : int'(rd), C[i][j]);
            end
        end
    endtask

    task automatic clear_irq;
        logic [DW-1:0] rd;
        write_csr(ADDR_IRQ, 1 << IRQ_DONE_BIT);
        read_csr(ADDR_STATUS, rd);
        check($sformatf("t%0d done cleared", t), rd[STATUS_DONE_BIT], 1'b0);
        check($sformatf("t%0d irq cleared", t), o_irq, 1'b0);
    endtask

    initial begin
`ifdef DUMP
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_matmul_accel);
`endif
        $display("MATMUL ACCEL TB: N=%0d EW=%0d RW=%0d job_cycles=%0d", N, EW, RW, JOB_CYCLES);

        dut_reset();
        csr_test();

        for (t = 0; t < CASES; t++) begin
            sign = (t >= 3);
            gen_matrices();
            matmul();
            load_matrices();
            run_job();
            read_result();
            clear_irq();
        end

        $display("RESULT: %0d passed, %0d failed", pass, fail);
        if (fail != 0) begin
            $fatal(1, "tb_matmul_accel FAILED (%0d checks)", fail);
        end
        $finish;
    end

    // timeout
    initial begin
        #1000000;
        $fatal(1, "tb_matmul_accel TIMEOUT");
    end
endmodule
