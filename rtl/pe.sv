`default_nettype none
`timescale 1ps/1ps

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 16
)(
    input wire clk,
    input wire rstn,
    input wire i_enable, // compute
    input wire i_clear,// clear accumulator
    input wire i_signed,
    input wire [DATA_WIDTH-1:0] i_a,
    input wire [DATA_WIDTH-1:0] i_b,
    output wire [DATA_WIDTH-1:0] o_a,
    output wire [DATA_WIDTH-1:0] o_b,
    output wire [ACC_WIDTH-1:0] o_psum
);
    logic [DATA_WIDTH-1:0] a_r, b_r;
    always_ff @(posedge clk) begin
        if (!rstn || i_clear) begin
            a_r <= '0;
            b_r <= '0;
        end else if (i_enable) begin
            a_r <= i_a;
            b_r <= i_b;
        end
    end

    logic a_s_bit, b_s_bit;
    assign a_s_bit = i_signed ? i_a[DATA_WIDTH-1] : 1'b0;
    assign b_s_bit = i_signed ? i_b[DATA_WIDTH-1] : 1'b0;

    logic signed [DATA_WIDTH:0] a_extend, b_extend;
    assign a_extend = {a_s_bit, i_a};
    assign b_extend = {b_s_bit, i_b};

    logic signed [2*DATA_WIDTH+1:0] mult_r;
    logic signed [ACC_WIDTH-1:0] accumulator, next_acc;

    assign mult_r = a_extend * b_extend;

    always_comb begin
        next_acc = accumulator + ACC_WIDTH'(mult_r);
    end

    always_ff @(posedge clk) begin
        if (!rstn || i_clear) begin
            accumulator <= '0;
        end else if (i_enable) begin
            accumulator <= next_acc;
        end
    end

    assign o_psum = accumulator;
    assign o_a = a_r;
    assign o_b = b_r;

endmodule
`default_nettype wire
