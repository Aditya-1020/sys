`timescale 1ps/1ps

module tb_top;
    localparam int unsigned DW = 32;
    localparam int unsigned N  = 4;
    localparam int unsigned EW = 8;

    localparam time CLK_HALF  = 5ns;
    localparam time SCLK_HALF = 2*CLK_HALF; // sclk = clk/2

    localparam int SGN_MIN = -(1 << (EW-1));

    localparam logic [7:0] CMD_CTRL_WR   = 8'h80;
    localparam logic [7:0] CMD_STATUS_RD = 8'h01;
    localparam logic [7:0] CMD_A_WR      = 8'hA0;
    localparam logic [7:0] CMD_B_WR      = 8'hB0;
    localparam logic [7:0] CMD_C_RD      = 8'h40;

    localparam int ST_AEMPTY = 1, ST_RESV = 4;

    localparam int JOBS  = 32; // back to back jobs, override with +JOBS=
    localparam int PRIME = 8;  // jobs in flight before reads start

    int njobs = JOBS;

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

    int B [N][N];
    int AQ [][N][N], CQ [][N][N];
    int pass, fail;

    task automatic check(input string name, input int got, input int exp);
        if (got === exp) pass++;
        else begin
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

    // spi mode 0
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
        #3ns; // keep the frame off the clk edge grid
        for (int i = 7; i >= 0; i--) spi_bit(cmd[i], rx);
    endtask

    task automatic frame_end;
        #(SCLK_HALF);
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        #(SCLK_HALF);
        #2ns;
    endtask

    task automatic wr_word(input logic [DW-1:0] w);
        logic rx;
        for (int i = DW-1; i >= 0; i--) spi_bit(w[i], rx);
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
        repeat (8) spi_bit(1'b0, rx);
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

    task automatic gen_jobs;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                B[i][j] = $urandom_range(0, 255) + SGN_MIN;
        AQ = new [njobs];
        CQ = new [njobs];
        for (int m = 0; m < njobs; m++) begin
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
        logic [DW-1:0] word = '0;
        for (int j = 0; j < N; j++) word[EW*j +: EW] = M[i][j][EW-1:0];
        return word;
    endfunction

    task automatic load_b;
        frame_begin(CMD_B_WR);
        for (int i = 0; i < N; i++) wr_word(pack_row(B, i));
        frame_end();
    endtask

    task automatic push_a(input int m);
        frame_begin(CMD_A_WR);
        for (int i = 0; i < N; i++) wr_word(pack_row(AQ[m], i));
        frame_end();
    endtask

    task automatic read_c(input int m);
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

    // pressure probe: in_fifo level while the stream is interleaving
    bit mon_en;
    int min_level;
    always @(posedge clk)
        if (mon_en && int'(dut.u_accel.in_level_w) < min_level)
            min_level = int'(dut.u_accel.in_level_w);

    logic [DW-1:0] v;

    initial begin
`ifdef DUMP
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
`endif
        void'($value$plusargs("JOBS=%d", njobs));
        $display("TOP TB: %0d back to back jobs, prime %0d, N=%0d EW=%0d", njobs, PRIME, N, EW);

        dut_reset();
        gen_jobs();
        load_b();
        spi_reg_write(CMD_CTRL_WR, 32'h3); // en + irq en

        for (int m = 0; m < PRIME; m++) push_a(m);

        min_level = 255;
        mon_en = 1;
        for (int k = 0; k < njobs - PRIME; k++) begin
            push_a(k + PRIME);
            read_c(k);
        end
        mon_en = 0;
        for (int k = njobs - PRIME; k < njobs; k++) read_c(k);
        repeat (8) @(posedge clk);

        spi_reg_read(CMD_STATUS_RD, v);
        check("a empty after drain", int'(v[ST_AEMPTY]), 1);
        check("results drained", int'(v[ST_RESV]), 0);
        check("fifo never emptied under load", int'(min_level > 0), 1);
        $display("  min in_fifo level while streaming: %0d", min_level);

        $display("RESULT: %0d passed, %0d failed", pass, fail);
        if (fail != 0) $fatal(1, "tb_top FAILED (%0d checks)", fail);
        $display("TEST PASSED");
        $finish;
    end

    initial begin
        #10ms;
        $fatal(1, "tb_top TIMEOUT");
    end
endmodule
