`timescale 1ns/1ps

// tb_systolic_array: signed int8 matmul, A streamed one row (4x8b) per cycle.
//   results stream out one element per beat (row-major) with a valid/ready
//   handshake; odd test cases randomly deassert ready to exercise backpressure.
//   make xrun TOP=tb_systolic_array
module tb_systolic_array;
    parameter integer N = 4; // set via makefile, even
    parameter integer DW = 8;
    localparam integer RW = (2*DW) + $clog2(N); // 18
    localparam integer CASES = 12;
    localparam integer SGN_MAX = (1 << (DW-1)) - 1; //  127
    localparam integer SGN_MIN = -(1 << (DW-1));    // -128
    localparam integer LANE_W = $clog2(N);
    localparam integer ROW_W = N*DW; // 32

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rstn, i_start, i_a_valid;
    logic o_done, o_busy;
    logic [ROW_W-1:0] i_ld_a; // one A row per i_a_valid strobe
    logic [RW-1:0] o_result_data; // one result element per beat
    logic o_result_valid, i_result_ready;
    logic i_b_en;
    logic [LANE_W-1:0] i_b_lane;
    logic [ROW_W-1:0] i_b_wdata;

`ifdef GLS
    systolic_array dut (
`else
    systolic_array #(
        .MATRIX_SIZE (N),
        .DATA_WIDTH  (DW)
    ) dut (
`endif
        .clk            (clk),
        .rstn           (rstn),
        .i_start        (i_start),
        .i_a_valid      (i_a_valid),
        .i_ld_a         (i_ld_a),
        .i_b_en         (i_b_en),
        .i_b_lane       (i_b_lane),
        .i_b_wdata      (i_b_wdata),
        .o_result_data  (o_result_data),
        .o_result_valid (o_result_valid),
        .i_result_ready (i_result_ready),
        .o_done         (o_done),
        .o_busy         (o_busy)
    );

    int A [N][N], B [N][N], C [N][N];
    int pass, fail;

    task automatic check(input string name, input int got, input int exp);
        if (got === exp) begin
            pass++;
        end else begin
            fail++;
            $display("FAIL %s got %0d expected %0d", name, got, exp);
        end
    endtask

    task automatic matmul;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                C[i][j] = 0;
                for (int k = 0; k < N; k++)
                    C[i][j] += A[i][k] * B[k][j];
            end
    endtask

    task automatic load;
        @(negedge clk);
        i_a_valid <= 1'b1;
        i_b_en    <= 1'b1;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                i_ld_a   [DW*j +: DW] <= A[i][j][DW-1:0];
                i_b_wdata[DW*j +: DW] <= B[i][j][DW-1:0];
            end
            i_b_lane <= i[LANE_W-1:0];
            @(posedge clk);
        end
        i_a_valid <= 1'b0;
        i_b_en <= 1'b0;

        i_start <= 1'b1;
        @(posedge clk);
        i_start <= 1'b0;
    endtask

    task automatic reset_dut;
        rstn <= 1'b0;
        i_ld_a <= '0;
        i_a_valid <= 1'b0;
        i_b_en <= 1'b0;
        i_b_lane <= '0;
        i_b_wdata <= '0;
        i_start <= 1'b0;
        i_result_ready <= 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rstn <= 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
    endtask

    task automatic collect_and_check(input int t, input bit do_stall);
        int idx;
        logic rdy;
        idx = 0;
        while (idx < N*N) begin
            @(negedge clk);
            rdy = do_stall ? ($urandom_range(0, 3) != 0) : 1'b1;
            i_result_ready <= rdy;
            if (o_result_valid && rdy) begin
                check($sformatf("t%0d C[%0d][%0d]", t, idx/N, idx%N),
                      int'($signed(o_result_data)), C[idx/N][idx%N]);
                idx++;
            end
        end
        i_result_ready <= 1'b1;
    endtask

    initial begin
`ifdef DUMP
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_systolic_array);
`endif
        $display("SYSTOLIC ARRAY TB: N=%0d DW=%0d RW=%0d", N, DW, RW);

        reset_dut();
        check("idle busy", int'(o_busy), 0);
        check("idle done", int'(o_done), 0);

        for (int t = 0; t < CASES; t++) begin
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    case (t)
                        0: begin // small positives
                            A[i][j] = (i*N + j + 1);
                            B[i][j] = (N*N - (i*N + j));
                        end
                        1: begin // identity weight
                            A[i][j] = (i*N + j + 1);
                            B[i][j] = (i == j) ? 1 : 0;
                        end
                        2: begin // max positive magnitude
                            A[i][j] = SGN_MAX;
                            B[i][j] = SGN_MAX;
                        end
                        3: begin // max negative magnitude
                            A[i][j] = SGN_MIN;
                            B[i][j] = SGN_MIN;
                        end
                        4: begin // alternating extremes
                            A[i][j] = (((i+j) % 2) != 0) ? SGN_MAX : SGN_MIN;
                            B[i][j] = (((i+j) % 2) != 0) ? SGN_MIN : SGN_MAX;
                        end
                        default: begin // random signed int8
                            A[i][j] = $urandom_range(0, 255) + SGN_MIN;
                            B[i][j] = $urandom_range(0, 255) + SGN_MIN;
                        end
                    endcase

            matmul();
            load();
            collect_and_check(t, t[0]);  // odd cases apply backpressure stalls
        end

        $display("RESULT: %0d passed, %0d failed", pass, fail);
        if (fail != 0) begin
            $fatal(1, "tb_systolic_array FAILED (%0d checks)", fail);
        end
        $display("TEST PASSED");
        $finish;
    end

    // timeout
    initial begin
        #1000000;
        $fatal(1, "tb_systolic_array TIMEOUT");
    end
endmodule
