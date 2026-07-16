`timescale 1ps/1ps

module tb_top;
    localparam int unsigned AW = 8;  // csr addr width
    localparam int unsigned DW = 32; // csr data width
    localparam int unsigned N = 4;
    localparam int unsigned EW = 8;

    localparam int unsigned CMD_BITS = 8;
    localparam int unsigned FRAME_BITS = CMD_BITS + AW + DW;
    localparam logic [CMD_BITS-1:0] CMD_WR = 8'h80; // msb cmd byte
    localparam logic [CMD_BITS-1:0] CMD_RD = 8'h00;

    localparam time CLK_HALF = 5ns;
    localparam time CLK_PERIOD = 2*CLK_HALF;
    localparam time SCLK_HALF = 8*CLK_HALF;

    localparam int unsigned JOB_CYCLES = 3*N + 2; // array compute time

    localparam logic [AW-1:0] ADDR_CTRL = 'h00;
    localparam logic [AW-1:0] ADDR_STATUS = 'h04;
    localparam logic [AW-1:0] ADDR_CYCLES = 'h08;
    localparam logic [AW-1:0] ADDR_IRQ = 'h0C;
    localparam logic [AW-1:0] ADDR_A_BASE = 'h10;
    localparam logic [AW-1:0] ADDR_B_BASE = 'h20;
    localparam logic [AW-1:0] ADDR_C_BASE = 'h40;
    localparam int CTRL_START_BIT = 0;
    localparam int CTRL_IRQ_EN_BIT = 2;
    localparam int STATUS_BUSY_BIT = 0;
    localparam int STATUS_DONE_BIT = 1;
    localparam int IRQ_DONE_BIT = 0;

    logic rstn;
    logic spi_sclk, spi_cs_n, spi_mosi;
    wire  spi_miso, o_irq;

    logic clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    top #(
        .CSR_ADDR_W (AW),
        .CSR_DATA_W (DW)
    ) dut (
        .clk      (clk),
        .rstn     (rstn),
        .spi_sclk (spi_sclk),
        .spi_cs_n (spi_cs_n),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .o_irq    (o_irq)
    );

    int A [N][N], B [N][N], C [N][N];
    int pass, fail;

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
        rstn = 1'b0;
        spi_sclk = 1'b0;
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rstn = 1'b1;
        repeat (5) @(posedge clk);
    endtask

    task automatic spi_xfer(input logic [FRAME_BITS-1:0] tx, output logic [FRAME_BITS-1:0] rx);
        rx = '0;
        spi_cs_n = 1'b0;
        #(SCLK_HALF);
        for (int i = FRAME_BITS-1; i >= 0; i--) begin
            spi_mosi = tx[i];
            #(SCLK_HALF);
            spi_sclk = 1'b1;
            #(SCLK_HALF/2);
            rx = {rx[FRAME_BITS-2:0], spi_miso};
            #(SCLK_HALF/2);
            spi_sclk = 1'b0;
        end
        #(SCLK_HALF);
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        #(SCLK_HALF);
    endtask

    task automatic spi_write(input logic [AW-1:0] addr, input logic [DW-1:0] data);
        logic [FRAME_BITS-1:0] rx;
        spi_xfer({CMD_WR, addr, data}, rx);
    endtask

    // rdata lands in the data phase of the same frame that carries the address
    task automatic spi_read(input logic [AW-1:0] addr, output logic [DW-1:0] data);
        logic [FRAME_BITS-1:0] rx;
        spi_xfer({CMD_RD, addr, {DW{1'b0}}}, rx);
        data = rx[DW-1:0];
    endtask

    // small non trivial operands plus the reference product
    task automatic gen_matrices;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A[i][j] = i*N + j + 1;
                B[i][j] = (3*i + j) % 5;
            end
        end
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
            spi_write(ADDR_A_BASE + AW'(4*i), word_a);
            spi_write(ADDR_B_BASE + AW'(4*i), word_b);
        end
    endtask

    function automatic string fmt(input time t);
        return $sformatf("%0d ns (%0d clk)", t/1ns, t/CLK_PERIOD);
    endfunction

    logic [DW-1:0] rd;
    logic [DW-1:0] cycles_csr;
    time t_load0, t_load1, t_start0, t_irq, t_read0, t_read1;

    initial begin
`ifdef DUMP
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
`endif
        $display("TOP TB: spi -> csr -> matmul, N=%0d EW=%0d, clk 100MHz sclk clk/8", N, EW);

        dut_reset();
        check("irq low after reset", o_irq, 1'b0);

        gen_matrices();

        t_load0 = $time;
        load_matrices();
        t_load1 = $time;

        t_start0 = $time;
        spi_write(ADDR_CTRL, (1 << CTRL_START_BIT) | (1 << CTRL_IRQ_EN_BIT));
        wait (o_irq);
        t_irq = $time;

        spi_read(ADDR_STATUS, rd);
        check("status done", rd[STATUS_DONE_BIT], 1'b1);
        check("status idle", rd[STATUS_BUSY_BIT], 1'b0);

        spi_read(ADDR_CYCLES, cycles_csr);
        check("core compute cycles", int'(cycles_csr), JOB_CYCLES);

        t_read0 = $time;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                spi_read(ADDR_C_BASE + AW'(4*(N*i + j)), rd);
                check($sformatf("C[%0d][%0d]", i, j), int'(rd), C[i][j]);
            end
        end
        t_read1 = $time;

        spi_write(ADDR_IRQ, 1 << IRQ_DONE_BIT);
        spi_read(ADDR_STATUS, rd);
        check("done cleared", rd[STATUS_DONE_BIT], 1'b0);
        check("irq cleared", o_irq, 1'b0);

        $display("TIMING at 100MHz, one 48b spi frame per 32b csr word");
        $display("  load a+b, 8 words   : %s", fmt(t_load1 - t_load0));
        $display("  per word            : %s", fmt((t_load1 - t_load0) / 8));
        $display("  start wr -> irq     : %s  (includes the start frame)", fmt(t_irq - t_start0));
        $display("  core compute        : %0d clk (%0d ns)", cycles_csr, cycles_csr * (CLK_PERIOD/1ns));
        $display("  read c, 16 words    : %s", fmt(t_read1 - t_read0));
        $display("  end to end          : %s", fmt(t_read1 - t_load0));

        $display("RESULT: %0d passed, %0d failed", pass, fail);
        if (fail != 0) begin
            $fatal(1, "tb_top FAILED (%0d checks)", fail);
        end
        $finish;
    end

    // timeout
    initial begin
        #500us;
        $fatal(1, "tb_top TIMEOUT");
    end
endmodule
