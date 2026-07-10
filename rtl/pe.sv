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
        a_r <= i_a;
        b_r <= i_b;
    end

    wire a_s_bit = i_signed ? a_r[DATA_WIDTH-1] : 1'd0;
    wire b_s_bit = i_signed ? b_r[DATA_WIDTH-1] : 1'd0;

    wire signed [DATA_WIDTH:0] a_w = {a_s_bit, a_r};
    wire signed [DATA_WIDTH:0] b_w = {b_s_bit, b_r};

    logic signed [2*DATA_WIDTH+1:0] mult_r;    
    logic signed [ACC_WIDTH-1:0] accumulator;
        
    always_ff @(posedge clk) begin
        if (!rstn || i_clear) begin
            accumulator <= '0;
            mult_r <= '0;
        end else if (i_enable) begin
            mult_r <= a_w * b_w;
            accumulator <= accumulator + mult_r;
        end
    end

    assign o_psum = accumulator;
    assign o_a = a_r;
    assign o_b = b_r;

endmodule
`default_nettype wire
