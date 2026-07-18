`timescale 1ns/1ps

module tb_systolic_array;
    parameter integer N = 4; // set using makefile even
    parameter integer DW = 8;
    localparam integer RW = (2*DW) + $clog2(N);
    localparam integer PRW = (N*N) * RW;
    localparam integer PW = N*N*DW;
    localparam integer LATENCY = 3*N+1;
    localparam integer CASES = 12;
    localparam integer UNS_MAX = (1 << DW) - 1;
    localparam integer SGN_MAX = (1 << (DW-1)) - 1;
    localparam integer SGN_MIN = -(1 << (DW-1));
    localparam integer LANE_W = $clog2(N);
    localparam integer ROW_W = N*DW;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rstn, i_start;
    logic o_done, o_busy;
    logic i_pe_sign_en;
    logic [PW-1:0] i_ld_a;//, i_ld_b;
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
        .i_ld_a        (i_ld_a),
        // .i_ld_b        (i_ld_b),
        .i_b_en(i_b_en),
        .i_b_lane(i_b_lane),
        .i_b_wdata(i_b_wdata),
        .i_pe_sign_en  (i_pe_sign_en),
        .i_start       (i_start),
        .o_result_data (o_result_data),
        .o_done        (o_done),
        .o_busy        (o_busy)
    );

    int A [N][N], B [N][N], C [N][N];
    int pass, fail;
    bit sign;

    task automatic check(input string name, input int got, input int exp);
        if (got === exp) begin
            pass++;
            $display("PASS %s got %0d", name, got);
        end else begin
            fail++;
            $display("FAIL %s got %0d expected %0d", name, got, exp);
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
    
    task automatic load;
        @(posedge clk);
        i_pe_sign_en <= sign;

        // A: whole matrix on the flat bus, held stable through COMPUTE
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                i_ld_a[DW*(N*i + j) +: DW] <= A[i][j][DW-1:0];

        // B: one row per cycle — lane selects the row, en strobes the write
        i_b_en <= 1'b1;
        for (int i = 0; i < N; i++) begin
            i_b_lane <= i[1:0];                       // row index
            for (int j = 0; j < N; j++)
                i_b_wdata[DW*j +: DW] <= B[i][j][DW-1:0];
            @(posedge clk);                           // array latches this row
        end
        i_b_en <= 1'b0;

        // kick off
        i_start <= 1'b1;
        @(posedge clk);
        i_start <= 1'b0;
    endtask

    task automatic reset_dut;
        rstn <= 1'b0;
        i_ld_a <= '0;
        // i_ld_b <= '0;
        i_b_en <= '0;
        i_b_lane <= '0;
        i_b_wdata <= '0;
        i_pe_sign_en <= 1'b0;
        i_start <= 1'b0;
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
            sign = (t >= 4);

            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    case (t)
                        0: begin
                            A[i][j] = (i*N + j + 1) % (UNS_MAX + 1);
                            B[i][j] = (N*N - (i*N + j)) % (UNS_MAX + 1);
                        end
                        1: begin
                            A[i][j] = (i*N + j + 1) % (UNS_MAX + 1);
                            B[i][j] = (i == j);
                        end
                        2: begin
                            A[i][j] = UNS_MAX;
                            B[i][j] = UNS_MAX;
                        end
                        4: begin
                            A[i][j] = ((i+j) % 2) ? SGN_MAX : SGN_MIN;
                            B[i][j] = (N*N - (i*N + j)) % (SGN_MAX + 1);
                        end
                        5: begin
                            A[i][j] = ((i+j) % 2) ? SGN_MAX : SGN_MIN;
                            B[i][j] = ((i+j) % 2) ? SGN_MAX : SGN_MIN;
                        end
                        default: begin
                            A[i][j] = $urandom_range(0, UNS_MAX) + (sign ? SGN_MIN : 0);
                            B[i][j] = $urandom_range(0, UNS_MAX) + (sign ? SGN_MIN : 0);
                        end
                    endcase

            matmul();
            load();
            wait_done(lat);
            check($sformatf("t%0d latency", t), lat, LATENCY);

            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    check($sformatf("t%0d C[%0d][%0d]", t, i, j), sign ? int'($signed(o_result_data[RW*(i*N + j) +: RW])) : int'(o_result_data[RW*(i*N + j) +: RW]), C[i][j]);
                end
            end
        end

        $display("RESULT: %0d passed, %0d failed ",pass, fail);
        if (fail != 0) begin
            $fatal(1, "tb_systolic_array FAILED (%0d checks)", fail);
        end
        $finish;
    end

    // timout
    initial begin
        #1000000;
        $fatal(1, "tb_systolic_array TIMEOUT");
    end
endmodule
