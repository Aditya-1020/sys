`timescale 1ps/1ps

interface dut_if #(
    parameter int in_w  = 16,
    parameter int out_w = 34
)(
    input logic clk
);
    logic rstn;
    logic w_load;
    logic signed [in_w-1:0] w_row;
    logic signed [in_w-1:0] a;
    logic signed [out_w-1:0] c;

    clocking cb @(posedge clk);
        default input #1step output #0;
        output w_load, w_row, a;
        input  c;
    endclocking
endinterface

module tb_systolic_array;

    localparam int pe_data_w = 8;
    localparam int pe_n = 2;
    localparam int in_w = pe_n * pe_data_w;
    localparam int acc_w = (2 * pe_data_w) + $clog2(pe_n);
    localparam int out_w = pe_n * acc_w;
    localparam int pe_lat = (2 * pe_n) - 1;
    localparam int n_vec = 2;

    typedef logic signed [pe_data_w-1:0] row_t [pe_n];

    row_t weights [pe_n]  = '{'{1, 2}, '{3, 4}};
    row_t acts [n_vec] = '{'{5, 6}, '{7, 8}};

    bit clk;
    int n_errors;
    event stream_start;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    dut_if #(.in_w(in_w), .out_w(out_w)) vif (clk);

    systolic_array #(
        .pe_n     (pe_n),
        .pe_data_w(pe_data_w)
    ) dut (
        .clk     (clk),
        .rstn    (vif.rstn),
        .i_w_load(vif.w_load),
        .i_w_row (vif.w_row),
        .i_a     (vif.a),
        .o_c     (vif.c)
    );

    function automatic logic signed [in_w-1:0] pack_row(row_t row);
        logic signed [in_w-1:0] flat;
        for (int i = 0; i < pe_n; i++) begin
            flat[i*pe_data_w +: pe_data_w] = row[i];
        end
        return flat;
    endfunction

    function automatic logic signed [acc_w-1:0] golden(int v, int col);
        logic signed [acc_w-1:0] acc;
        acc = '0;
        for (int r = 0; r < pe_n; r++) begin
            acc += acc_w'(acts[v][r] * weights[r][col]);
        end
        return acc;
    endfunction

    task automatic reset_dut();
        vif.rstn = 1'b0;
        vif.w_load = 1'b0;
        vif.w_row = '0;
        vif.a = '0;
        $display("[%0t] reset asserted", $time);
        repeat (10) @(vif.cb);
        vif.rstn = 1'b1;
        $display("[%0t] reset de-asserted", $time);
    endtask

    // rows push sobottom row driven first
    task automatic drive_weights();
        $display("[%0t] loading weights", $time);
        for (int r = pe_n - 1; r >= 0; r--) begin
            @(vif.cb);
            vif.cb.w_load <= 1'b1;
            vif.cb.w_row <= pack_row(weights[r]);
        end
        @(vif.cb);
        vif.cb.w_load <= 1'b0;
        vif.cb.w_row <= '0;
        $display("[%0t] weights loaded", $time);
    endtask

    task automatic drive_activations();
        $display("[%0t] streaming activations", $time);
        for (int v = 0; v < n_vec; v++) begin
            @(vif.cb);
            vif.cb.a <= pack_row(acts[v]);
            if (v == 0) ->stream_start;
        end
        @(vif.cb);
        vif.cb.a <= '0;
        $display("[%0t] activations streamed", $time);
    endtask

    // no valid signal on the DUT sample results on a counted schedule
    task automatic check_results();
        logic signed [out_w-1:0] got_bus;
        logic signed [acc_w-1:0] got_c, exp_c;
        @(stream_start);
        repeat (pe_lat + 1) @(vif.cb);
        for (int v = 0; v < n_vec; v++) begin
            got_bus = vif.cb.c;
            for (int col = 0; col < pe_n; col++) begin
                got_c = got_bus[col*acc_w +: acc_w];
                exp_c = golden(v, col);
                if (got_c !== exp_c) begin
                    n_errors++;
                    $display("[%0t] FAIL | vec %0d col %0d | got %0d expected %0d", $time, v, col, got_c, exp_c);
                end else begin
                    $display("[%0t] PASS | vec %0d col %0d | c = %0d", $time, v, col, got_c);
                end
            end
            @(vif.cb);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_systolic_array);

        reset_dut();

        fork
            begin
                drive_weights();
                drive_activations();
            end
            check_results();
        join

        if (n_errors == 0) $display("[%0t] TEST PASSED | %0d vectors checked", $time, n_vec);
        else $display("[%0t] TEST FAILED | %0d errors", $time, n_errors);
        $finish;
    end

    initial begin
        #2000;
        $display("[%0t] TIMEOUT", $time);
        $finish;
    end

endmodule
