`timescale 1ns/1ps

// tb_systolic_array: signed int8 matmul, A streamed in one row (4x8b) per cycle.
//   make xrun TOP=tb_systolic_array
module tb_systolic_array;
    parameter integer N = 4; // set via makefile, even
    parameter integer DW = 8;
    localparam integer RW = (2*DW) + $clog2(N); // 18
    localparam integer PRW = (N*N) * RW;
    localparam integer LATENCY = 3*N; // one cycle shorter: no left-edge feed register
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
    logic [PRW-1:0] o_result_data;
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
        .clk           (clk),
        .rstn          (rstn),
        .i_start       (i_start),
        .i_a_valid     (i_a_valid),
        .i_ld_a        (i_ld_a),
        .i_b_en        (i_b_en),
        .i_b_lane      (i_b_lane),
        .i_b_wdata     (i_b_wdata),
        .o_result_data (o_result_data),
        .o_done        (o_done),
        .o_busy        (o_busy)
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

    // stream A (one row/cycle) and load stationary weights B over the same window,
    // then pulse start. both land while the array is idle in LOAD.
    task automatic load;
        @(negedge clk);
        i_a_valid <= 1'b1;
        i_b_en    <= 1'b1;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                i_ld_a   [DW*j +: DW] <= A[i][j][DW-1:0]; // A row i
                i_b_wdata[DW*j +: DW] <= B[i][j][DW-1:0]; // B row i
            end
            i_b_lane <= i[LANE_W-1:0];
            @(posedge clk);
        end
        i_a_valid <= 1'b0;
        i_b_en    <= 1'b0;

        i_start <= 1'b1;
        @(posedge clk);
        i_start <= 1'b0;
    endtask

    task automatic reset_dut;
        rstn      <= 1'b0;
        i_ld_a    <= '0;
        i_a_valid <= 1'b0;
        i_b_en    <= 1'b0;
        i_b_lane  <= '0;
        i_b_wdata <= '0;
        i_start   <= 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rstn <= 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
    endtask

    task automatic wait_done(output int cycles);
        cycles = 0;
        forever begin
            @(posedge clk);
            cycles++;
            @(negedge clk);
            if (o_done) break;
        end
    endtask

    int lat;

    initial begin
`ifdef DUMP
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_systolic_array);
`endif
        $display("SYSTOLIC ARRAY TB: N=%0d DW=%0d RW=%0d latency=%0d", N, DW, RW, LATENCY);

        reset_dut();
        check("idle busy", o_busy, 1'b0);
        check("idle done", o_done, 1'b0);

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
                            B[i][j] = (i == j);
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
                            A[i][j] = ((i+j) % 2) ? SGN_MAX : SGN_MIN;
                            B[i][j] = ((i+j) % 2) ? SGN_MIN : SGN_MAX;
                        end
                        default: begin // random signed int8
                            A[i][j] = $urandom_range(0, 255) + SGN_MIN;
                            B[i][j] = $urandom_range(0, 255) + SGN_MIN;
                        end
                    endcase

            matmul();
            load();
            wait_done(lat);
            check($sformatf("t%0d latency", t), lat, LATENCY);

            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    check($sformatf("t%0d C[%0d][%0d]", t, i, j),
                          int'($signed(o_result_data[RW*(i*N + j) +: RW])),
                          C[i][j]);
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
