`timescale 1ps/1ps

module tb_top;
    localparam int unsigned DW = 32;
    localparam int unsigned N = 4;
    localparam int unsigned EW = 8;

    localparam time CLK_HALF = 5ns;
    localparam time CLK_PERIOD = 2*CLK_HALF;
    localparam time SCLK_HALF = 2*CLK_HALF; // sclk = clk/2

    localparam int SGN_MIN = -(1 << (EW-1));

    localparam logic [7:0] CMD_CTRL_WR   = 8'h80;
    localparam logic [7:0] CMD_IRQ_WR    = 8'h82;
    localparam logic [7:0] CMD_CTRL_RD   = 8'h00;
    localparam logic [7:0] CMD_STATUS_RD = 8'h01;
    localparam logic [7:0] CMD_IRQ_RD    = 8'h02;
    localparam logic [7:0] CMD_A_WR      = 8'hA0;
    localparam logic [7:0] CMD_B_WR      = 8'hB0;
    localparam logic [7:0] CMD_C_RD      = 8'h40;

    localparam int ST_BUSY = 0, ST_AEMPTY = 1, ST_AFULL = 2, ST_DONE = 3, ST_RESV = 4;

    localparam int NMAT = 16;         // in_fifo capacity in matrices, 16 x 4 = all 64 sram words
    localparam int PRIME = 4;         // matrices queued before the sustained interleave starts
    localparam int IDLE_GAP_MAX = 16; // allowed ctrl handshake + sram refetch gap, in clk cycles

    logic rstn;
    logic spi_sclk, spi_cs_n, spi_mosi;
    wire  spi_miso, o_irq;

    logic clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    top #(
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
    int AQ [NMAT][N][N], CQ [NMAT][N][N];
    int pass, fail;

    task automatic check(input string name, input int got, input int exp);
        if (got === exp) begin
            pass++;
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

    // one spi bit, mode 0: mosi valid before the rise, miso sampled at the rise
    task automatic spi_bit(input logic tx, output logic rx);
        spi_mosi = tx;
        #(SCLK_HALF);
        spi_sclk = 1'b1;
        #(SCLK_HALF/2);
        rx = spi_miso;
        #(SCLK_HALF/2);
        spi_sclk = 1'b0;
    endtask

    task automatic frame_begin(input logic [7:0] cmd);
        logic rx;
        spi_cs_n = 1'b0;
        #3ns; // hold the whole frame off the clk edge grid
        for (int i = 7; i >= 0; i--) begin
            spi_bit(cmd[i], rx);
        end
    endtask

    task automatic frame_end;
        #(SCLK_HALF);
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        #(SCLK_HALF);
        #2ns; // realign to the clk grid for the next frame
    endtask

    task automatic wr_word(input logic [DW-1:0] w);
        logic rx;
        for (int i = DW-1; i >= 0; i--) begin
            spi_bit(w[i], rx);
        end
    endtask

    task automatic rd_word(output logic [DW-1:0] w);
        logic rx;
        w = '0;
        for (int i = DW-1; i >= 0; i--) begin
            spi_bit(1'b0, rx);
            w = {w[DW-2:0], rx};
        end
    endtask

    task automatic turnaround;
        logic rx;
        for (int i = 0; i < 8; i++) begin
            spi_bit(1'b0, rx);
        end
    endtask

    task automatic spi_reg_write(input logic [7:0] cmd, input logic [DW-1:0] data);
        frame_begin(cmd);
        wr_word(data);
        frame_end();
    endtask

    task automatic spi_reg_read(input logic [7:0] cmd, output logic [DW-1:0] data);
        frame_begin(cmd);
        turnaround();
        rd_word(data);
        frame_end();
    endtask

    // signed operands plus the reference product
    task automatic gen_matrices;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A[i][j] = $urandom_range(0, 255) + SGN_MIN;
                B[i][j] = $urandom_range(0, 255) + SGN_MIN;
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

    // per-matrix a operands against the stationary b, same golden convention
    task automatic gen_aq;
        for (int m = 0; m < NMAT; m++) begin
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    AQ[m][i][j] = $urandom_range(0, 255) + SGN_MIN;
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++) begin
                    CQ[m][i][j] = 0;
                    for (int k = 0; k < N; k++)
                        CQ[m][i][j] += AQ[m][i][k] * B[k][j];
                end
        end
    endtask

    function automatic [DW-1:0] pack_row(input int M [N][N], input int i);
        logic [DW-1:0] word;
        word = '0;
        for (int j = 0; j < N; j++) begin
            word[EW*j +: EW] = M[i][j][EW-1:0];
        end
        return word;
    endfunction

    function automatic string fmt(input time t);
        return $sformatf("%0d ns (%0d clk)", longint'(t/1ns), longint'(t/CLK_PERIOD));
    endfunction

    task automatic load_b_frame;
        frame_begin(CMD_B_WR);
        for (int i = 0; i < N; i++) wr_word(pack_row(B, i));
        frame_end();
    endtask

    task automatic push_a_frame(input int m);
        frame_begin(CMD_A_WR);
        for (int i = 0; i < N; i++) wr_word(pack_row(AQ[m], i));
        frame_end();
    endtask

    task automatic read_c_frame(input int m);
        logic [DW-1:0] w;
        frame_begin(CMD_C_RD);
        turnaround();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                rd_word(w);
                check($sformatf("m%0d C[%0d][%0d]", m, i, j), int'(w), CQ[m][i][j]);
            end
        frame_end();
    endtask

    bit [63:0] sram_wr_seen, sram_rd_seen;
    always @(posedge clk) begin
        if (dut.u_accel.u_in_fifo.accept)
            sram_wr_seen[dut.u_accel.u_in_fifo.wr_addr] <= 1'b1;
        if (dut.u_accel.u_in_fifo.read_issue)
            sram_rd_seen[dut.u_accel.u_in_fifo.rd_addr] <= 1'b1;
    end

    bit util_mon_en;
    int util_busy, util_total, idle_streak, max_idle_streak, min_level, interleave_min;
    always @(posedge clk) begin
        if (util_mon_en) begin
            util_total++;
            if (dut.u_accel.array_busy_w) begin
                util_busy++;
                idle_streak = 0;
            end else if ((dut.u_accel.in_level_w != '0) && !dut.u_accel.res_full_w) begin
                idle_streak++;
                if (idle_streak > max_idle_streak) max_idle_streak = idle_streak;
            end else begin
                idle_streak = 0;
            end
            if (int'(dut.u_accel.in_level_w) < min_level) min_level = int'(dut.u_accel.in_level_w);
        end else begin
            idle_streak = 0;
        end
    end

    task automatic test_fill_backpressure;
        logic [DW-1:0] v;
        $display("TEST fill_backpressure: %0d matrices, no result reads, full sram span", NMAT);
        dut_reset();
        gen_matrices();
        gen_aq();
        load_b_frame();

        for (int m = 0; m < NMAT; m++) push_a_frame(m);
        repeat (8) @(posedge clk);

        spi_reg_read(CMD_STATUS_RD, v);
        check("fill level 16", int'(v[15:8]), NMAT);
        check("fill full", int'(v[ST_AFULL]), 1);
        check("fill not empty", int'(v[ST_AEMPTY]), 0);
        check("fill wr_ready deasserted", int'(dut.u_accel.a_ready_w), 0);

        frame_begin(CMD_A_WR);
        for (int i = 0; i < N; i++) wr_word(32'hBAD0_0000 | i);
        frame_end();
        repeat (8) @(posedge clk);
        spi_reg_read(CMD_STATUS_RD, v);
        check("fill level still 16", int'(v[15:8]), NMAT);
        check("fill still full", int'(v[ST_AFULL]), 1);
        spi_reg_read(CMD_IRQ_RD, v);
        check("fill ovfl flagged", int'(v[1]), 1);
        spi_reg_write(CMD_IRQ_WR, 32'h2); // w1c

        spi_reg_write(CMD_CTRL_WR, 32'h3);
        wait (o_irq); // first results have landed in out_fifo
        frame_begin(CMD_C_RD);
        turnaround();
        for (int m = 0; m < NMAT; m++)
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++) begin
                    rd_word(v);
                    check($sformatf("fill m%0d C[%0d][%0d]", m, i, j), int'(v), CQ[m][i][j]);
                end
        frame_end();
        repeat (8) @(posedge clk);

        spi_reg_read(CMD_STATUS_RD, v);
        check("fill a empty after drain", int'(v[ST_AEMPTY]), 1);
        check("fill level 0 after drain", int'(v[15:8]), 0);
        check("fill results drained", int'(v[ST_RESV]), 0);
        check("fill all 64 sram words written", int'(&sram_wr_seen), 1);
        check("fill all 64 sram words read", int'(&sram_rd_seen), 1);
        $display("  sram words written %0d/64, read %0d/64",
                 $countones(sram_wr_seen), $countones(sram_rd_seen));
    endtask

    task automatic test_sustained;
        logic [DW-1:0] v;
        $display("TEST sustained: primed fifo, interleaved push/read, %0d matrices", NMAT);
        dut_reset();
        gen_matrices();
        gen_aq();
        load_b_frame();
        spi_reg_write(CMD_CTRL_WR, 32'h3);

        for (int m = 0; m < PRIME; m++) push_a_frame(m);

        util_busy = 0; util_total = 0; idle_streak = 0; max_idle_streak = 0;
        min_level = 255;
        util_mon_en = 1;

        for (int k = 0; k < NMAT - PRIME; k++) begin
            push_a_frame(k + PRIME);
            read_c_frame(k);
        end
        interleave_min = min_level;
        for (int k = NMAT - PRIME; k < NMAT; k++) begin
            read_c_frame(k);
        end
        util_mon_en = 0;
        repeat (8) @(posedge clk);

        spi_reg_read(CMD_STATUS_RD, v);
        check("sustained a empty", int'(v[ST_AEMPTY]), 1);
        check("sustained results drained", int'(v[ST_RESV]), 0);
        check("sustained fifo never emptied while interleaving", int'(interleave_min > 0), 1);
        check("sustained no idle beyond handshake gap", int'(max_idle_streak <= IDLE_GAP_MAX), 1);
        $display("  utilization: %0d/%0d busy cycles = %0d%%, max idle-with-work streak %0d (cap %0d), min level %0d", util_busy, util_total, (util_busy*100)/util_total, max_idle_streak, IDLE_GAP_MAX, interleave_min);
    endtask

    logic [DW-1:0] rd;
    time t_load0, t_load1, t_irq, t_read0, t_read1;

    initial begin
`ifdef DUMP
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
`endif
        $display("TOP TB: spi -> channels -> matmul, N=%0d EW=%0d, clk 100MHz sclk clk/2", N, EW);

        dut_reset();
        check("irq low after reset", int'(o_irq), 0);

        gen_matrices();

        // b burst, enable, a burst: one frame each, headerless words
        t_load0 = $time;
        frame_begin(CMD_B_WR);
        for (int i = 0; i < N; i++) wr_word(pack_row(B, i));
        frame_end();

        spi_reg_write(CMD_CTRL_WR, 32'h3); // en + irq en
        spi_reg_read(CMD_CTRL_RD, rd);
        check("ctrl readback over spi", int'(rd), 3);

        frame_begin(CMD_A_WR);
        for (int i = 0; i < N; i++) wr_word(pack_row(A, i));
        frame_end();
        t_load1 = $time;

        wait (o_irq); // results ready
        t_irq = $time;

        spi_reg_read(CMD_STATUS_RD, rd);
        check("status busy while draining", int'(rd[ST_BUSY]), 1);
        check("status result valid", int'(rd[ST_RESV]), 1);
        check("status a empty", int'(rd[ST_AEMPTY]), 1);
        check("status result level", int'(rd[23:16]), 4);

        // one c burst frame, one pop per word, row major, sign extended
        t_read0 = $time;
        frame_begin(CMD_C_RD);
        turnaround();
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                rd_word(rd);
                check($sformatf("C[%0d][%0d]", i, j), int'(rd), C[i][j]);
            end
        end
        frame_end();
        t_read1 = $time;

        spi_reg_read(CMD_STATUS_RD, rd);
        check("results drained", int'(rd[ST_RESV]), 0);
        check("status idle", int'(rd[ST_BUSY]), 0);
        check("status done", int'(rd[ST_DONE]), 1);

        spi_reg_write(CMD_IRQ_WR, 32'h1);
        spi_reg_read(CMD_IRQ_RD, rd);
        check("irq w1c", int'(rd), 0);
        check("irq cleared", int'(o_irq), 0);

        $display("TIMING at 100MHz, sclk = clk/2, headerless burst words");
        $display("  load b + ctrl + a   : %s", fmt(t_load1 - t_load0));
        $display("  last a wr -> irq    : %s", fmt(t_irq - t_load1));
        $display("  read c, 16 words    : %s", fmt(t_read1 - t_read0));
        $display("  end to end          : %s", fmt(t_read1 - t_load0));

        test_fill_backpressure();
        test_sustained();

        $display("RESULT: %0d passed, %0d failed", pass, fail);
        if (fail != 0) begin
            $fatal(1, "tb_top FAILED (%0d checks)", fail);
        end
        $display("TEST PASSED");
        $finish;
    end

    initial begin
        #4ms;
        $fatal(1, "tb_top TIMEOUT");
    end
endmodule
