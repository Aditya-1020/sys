`default_nettype none
`timescale 1ps/1ps

module pe #(
    parameter int unsigned XLEN = 8,
    parameter int unsigned OUTPUT_WIDTH = 32
)(
    input  wire clk,
    input  wire rstn,
    input  wire acc_en_i,
    input  wire acc_rst_i,
    input  wire signed [XLEN-1:0] input_i,
    input  wire signed [XLEN-1:0] weight_i,
    input  wire signed [OUTPUT_WIDTH-1:0] top_input_i,
    output logic signed [OUTPUT_WIDTH-1:0] output_o
);
    /* verilator lint_off UNUSEDPARAM */
    // localparam int unsigned PE_LATENCY = 3;
    /* verilator lint_on UNUSEDPARAM */
    localparam int unsigned PRODUCT_WIDTH = 2*XLEN;

    // register
    logic signed [XLEN-1:0] s1_input_r, s1_weight_r;
    logic signed [OUTPUT_WIDTH-1:0] s1_top_r;
    logic s1_acc_en_r, s1_acc_rst_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            s1_acc_en_r <= 1'b0;
            s1_acc_rst_r <= 1'b0;
            s1_top_r <= '0;
        end else begin
            s1_acc_en_r <= acc_en_i;
            s1_acc_rst_r <= acc_rst_i;
            s1_top_r <= top_input_i;
        end
    end

    always_ff @(posedge clk) begin
        s1_input_r <= input_i;
        s1_weight_r <= weight_i;
    end

    // multiply
    logic signed [PRODUCT_WIDTH-1:0] s2_prod_r;
    logic signed [OUTPUT_WIDTH-1:0] s2_top_r;
    logic s2_acc_en_r, s2_acc_rst_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            s2_top_r <= '0;
            s2_acc_en_r  <= 1'b0;
            s2_acc_rst_r <= 1'b0;
        end else begin
            s2_top_r <= s1_top_r;
            s2_acc_en_r  <= s1_acc_en_r;
            s2_acc_rst_r <= s1_acc_rst_r;
        end
    end

    always_ff @(posedge clk) begin
        s2_prod_r <= s1_input_r * s1_weight_r;
    end

    // accumulate
    logic signed [OUTPUT_WIDTH-1:0] s3_sum_c;

    always_comb begin
        s3_sum_c = s2_top_r;
        if (s2_acc_rst_r)
            s3_sum_c = '0;
        else if (s2_acc_en_r)
            s3_sum_c = OUTPUT_WIDTH'(s2_prod_r) + s2_top_r;
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            output_o <= '0;
        else
            output_o <= s3_sum_c;
    end

endmodule
`default_nettype wire
