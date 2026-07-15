`timescale 1ns/1ps

module tb_systolic_array;
    parameter int unsigned N = 4; // set using makefile even
    parameter int unsigned DW = 8;
    localparam int unsigned RW = (2*DW) + $clog2(N);
    localparam int unsigned PW = N*N*DW;
    localparam int unsigned LATENCY = 3*N + 1;
    localparam int unsigned CASES = 12;
    localparam int UNS_MAX = (1 << DW) - 1;
    localparam int SGN_MAX = (1 << (DW-1)) - 1;
    localparam int SGN_MIN = -(1 << (DW-1));

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rstn, i_ld_valid, o_ld_ready, i_pe_sign_en, i_result_ready, o_result_valid;
    logic [PW-1:0] i_ld_a, i_ld_b;
    logic [N*N-1:0][RW-1:0] o_result_data;

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
        .i_ld_valid    (i_ld_valid),
        .o_ld_ready    (o_ld_ready),
        .i_ld_a        (i_ld_a),
        .i_ld_b        (i_ld_b),
        .i_pe_sign_en  (i_pe_sign_en),
        .i_result_ready(i_result_ready),
        .o_result_valid(o_result_valid),
        .o_result_data (o_result_data)
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
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                i_ld_a[DW*(N*i + j) +: DW] <= A[i][j][DW-1:0];
                i_ld_b[DW*(N*i + j) +: DW] <= B[i][j][DW-1:0];
            end
        i_ld_valid <= 1'b1;
        do @(posedge clk); while (!o_ld_ready);
        i_ld_valid <= 1'b0;
    endtask

    int lat;
    logic [N*N-1:0][RW-1:0] snap;

    initial begin
`ifdef DUMP
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_systolic_array);
`endif
        $display("SYSTOIC ARRAY TB: N=%0d DW=%0d RW=%0d latency=%0d", N, DW, RW, LATENCY);

        rstn <= 1'b0;
        i_ld_valid <= 1'b0;
        i_ld_a <= '0;
        i_ld_b <= '0;
        i_pe_sign_en <= 1'b0;
        i_result_ready <= 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rstn <= 1'b1;
        repeat (2) @(posedge clk);

        check("idle ready", o_ld_ready, 1'b1);
        check("idle valid", o_result_valid, 1'b0);

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

            lat = 0;
            while (!o_result_valid) begin
                @(posedge clk);
                lat++;
            end
            check($sformatf("t%0d latency", t), lat, LATENCY);

            // back pressure
            if (t % 2) begin
                snap = o_result_data;
                repeat (3) @(posedge clk);
                check($sformatf("t%0d held", t), o_result_valid && (o_result_data === snap), 1'b1);
            end

            // compare at full width, so a too-narrow accumulator cannot wrap on
            // both sides and hide
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    check($sformatf("t%0d C[%0d][%0d]", t, i, j), sign ? int'($signed(o_result_data[i*N + j])) : int'(o_result_data[i*N + j]),
                          C[i][j]);

            i_result_ready <= 1'b1;
            @(posedge clk);
            i_result_ready <= 1'b0;
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
