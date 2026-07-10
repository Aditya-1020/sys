`default_nettype none
`timescale 1ps/1ps

module pe #(
    parameter int pe_data_w = 8, // activation/weight width
    parameter int pe_acc_w = 17  // psum width
)(
    input wire clk,
    input wire rstn,
    
    input wire i_acc_clear, // clear accumulator

    input wire i_w_load,
    input wire signed [(pe_data_w-1):0] i_w,
    output wire signed [(pe_data_w-1):0] o_w,

    input wire signed [(pe_data_w-1):0] i_a,
    output wire signed [(pe_data_w-1):0] o_a,

    input wire signed [(pe_acc_w-1):0] i_psum,
    output wire signed [(pe_acc_w-1):0] o_psum
);
    wire signed [(2*pe_data_w)-1:0] product;
    wire signed [pe_acc_w-1:0] next_psum;

    reg signed [pe_data_w-1:0] a_r;
    reg signed [pe_data_w-1:0] w_r; // shift-register and stationary Store
    reg signed [pe_acc_w-1:0] psum_r; 

    assign product = i_a * w_r; // activation * stored weight
    
    // accumulate
    assign next_psum = i_psum + pe_acc_w'(product);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            a_r <= '0;
            psum_r <= '0;
        end else begin
            a_r <= i_a;
            if (i_acc_clear && !i_w_load) begin
                psum_r <= '0;
            end else if (!i_w_load) begin
                psum_r <= next_psum;
            end
        end
    end

    always_ff @(posedge clk) begin // pre load weight
        if (i_w_load) begin
            w_r <= i_w;
        end else begin
            w_r <= w_r; // hold weight
        end
    end

    assign o_a = a_r;
    assign o_psum = psum_r;
    assign o_w = w_r; 
    
endmodule
`default_nettype wire
