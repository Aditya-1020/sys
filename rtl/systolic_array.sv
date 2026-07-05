`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter int unsigned N = 2,
    parameter int unsigned XLEN = 8,
    parameter int unsigned OUTPUT_WIDTH = 32,
    parameter int unsigned PE_LATENCY = 3
)(
    input wire clk,
    input wire rstn,
    input wire acc_en_i,
    input wire acc_rst_i,
    input wire signed [XLEN-1:0] input_row [N], // one activation per row, stream one vector per cycle
    input wire signed [XLEN-1:0] weight_arr [N][N], // stationary weights
    output logic signed [OUTPUT_WIDTH-1:0] output_arr [N][N] // row N-1 = result stream
);
    logic acc_en_skew [N];
    logic acc_rst_skew [N];
    logic signed [XLEN-1:0] input_skew [N];

    skew_feeder #(
        .N(N),
        .XLEN(XLEN),
        .PE_LATENCY(PE_LATENCY)
    ) u_skew (
        .clk(clk),
        .rstn(rstn),
        .acc_en_i(acc_en_i),
        .acc_rst_i(acc_rst_i),
        .input_row_i(input_row),
        .acc_en_o(acc_en_skew),
        .acc_rst_o(acc_rst_skew),
        .input_row_o(input_skew)
    );

    // psum; top_net[r][c] feeds PE[r][c] from above
    // PE[r][c] drives top_net[r+1][c]
    wire signed [OUTPUT_WIDTH-1:0] top_net [N+1][N];

    for (genvar c = 0; c < N; c++) begin : g_psum_init
        assign top_net[0][c] = '0;
    end

    for (genvar r = 0; r < N; r++) begin : g_row
        for (genvar c = 0; c < N; c++) begin : g_col
            pe #(.XLEN(XLEN), .OUTPUT_WIDTH(OUTPUT_WIDTH)) u_pe (
                .clk(clk),
                .rstn(rstn),
                .acc_en_i(acc_en_skew[r]),
                .acc_rst_i(acc_rst_skew[r]),
                .input_i(input_skew[r]),
                .weight_i(weight_arr[r][c]),
                .top_input_i(top_net[r][c]),
                .output_o(top_net[r+1][c])
            );
            assign output_arr[r][c] = top_net[r+1][c];
        end
    end

endmodule
`default_nettype wire