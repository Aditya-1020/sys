`default_nettype none
`timescale 1ps/1ps

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input wire clk,
    input wire rstn,
    input wire i_enable, // compute
    input wire i_clear,// clear accumulator
    input wire i_signed,
    input wire [DATA_WIDTH-1:0] i_a,
    output logic [DATA_WIDTH-1:0] o_a,
    input wire [DATA_WIDTH-1:0] i_b,
    output logic [DATA_WIDTH-1:0] o_b,
    output wire [ACC_WIDTH-1:0] o_psum
);
    wire a_s_bit = i_signed ? i_a[DATA_WIDTH-1] : 1'd0;
    wire b_s_bit = i_signed ? i_b[DATA_WIDTH-1] : 1'd0;
    
    logic signed [ACC_WIDTH-1:0] accumulator;
    wire signed [DATA_WIDTH:0] a_w = {a_s_bit, i_a};
    wire signed [DATA_WIDTH:0] b_w = {b_s_bit, i_b};
    
    wire signed [2*DATA_WIDTH+1:0] mult_res = a_w * b_w;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            o_a <= '0;
            o_b <= '0;
        end else begin
            o_a <= i_a;
            o_b <= i_b;
        end
    end

    always @(posedge clk) begin
        if (!rstn || i_clear) begin
            accumulator <= '0;
        end else if (i_enable) begin
            accumulator <= accumulator + mult_res;
        end
    end

    assign o_psum = accumulator;

endmodule
`default_nettype wire
