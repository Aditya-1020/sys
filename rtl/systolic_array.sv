/*
- Activations (left edge)
    - delay row 0 = 0 cycle
    - delay row 1 = 1 cycle
    - N = n cycle delay
- weights: weights vertical streamed and registed duign LOAD
    - no skew just pushed the rows down in N cycles
- output: 
    - col 0 = N cycles ouput
    - col n-1 = last to output
    - col 0 dealyed n-1 cycles and col n-1 delayed 0 cycles for output at same time
*/

`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter integer pe_n = 2, // array dimension
    parameter integer pe_data_w = 8 // activation/weight width
)(
    input wire clk,
    input wire rstn,

    input wire i_acc_clear_pe,

    // weight fed from top edge
    input wire i_w_load,
    input logic signed [(pe_n*pe_data_w)-1:0] i_w_row,
    
    // activations fed from left edge
    input logic signed [(pe_n*pe_data_w)-1:0] i_a,
    output logic signed [(pe_n * ( (2 * pe_data_w) + $clog2(pe_n) ))-1:0] o_c
);
    localparam integer pe_acc_w = (2 * pe_data_w) + $clog2(pe_n); // accumulator width
    localparam integer pe_lat = (2*pe_n)-1; // total pipeline latecy

    wire signed [pe_data_w-1:0] weight_w [pe_n+1][pe_n];
    wire signed [pe_data_w-1:0] act_w [pe_n][pe_n+1];
    wire signed [pe_acc_w-1:0] psum_w [pe_n+1][pe_n];

    logic signed [pe_data_w-1:0] a_skew [pe_n]; // input skew for left edge activations

    // input skew
    generate
        for (genvar r = 0; r < pe_n; r = r + 1) begin : gen_a_skew
            if (r == 0) begin
                // no delay r=0
                assign a_skew[r] = signed'(i_a[r*pe_data_w +: pe_data_w]);
            end else begin
                // r = r cycle delay
                logic signed [pe_data_w-1:0] delay_r [r:1];
                always_ff @(posedge clk or negedge rstn) begin
                    if (!rstn) begin
                        for (int i = 1; i <= r; i = i + 1) begin
                            delay_r[i] <= '0;
                        end
                    end else begin
                        delay_r[1] <= signed'(i_a[r*pe_data_w +: pe_data_w]);
                        for (int i = 2; i <= r; i = i + 1) begin
                            delay_r[i] <= delay_r[i-1];
                        end
                    end
                end
                assign a_skew[r] = delay_r[r];
            end
            assign act_w[r][0] = a_skew[r];
        end
    endgenerate

    // top edge
    generate
        for (genvar c = 0; c < pe_n; c=c+1) begin : gen_top_edge
            assign weight_w[0][c] = signed'(i_w_row[c*pe_data_w +: pe_data_w]);
            assign psum_w[0][c] = '0;
        end
    endgenerate

    // pe array
    generate
        for (genvar r = 0; r < pe_n; r = r + 1) begin : pe_row
            for (genvar c = 0; c < pe_n; c = c + 1) begin : pe_col
                pe #(
                    .pe_data_w(pe_data_w),
                    .pe_acc_w(pe_acc_w)
                    ) u_pe (
                        .clk    (clk),
                        .rstn   (rstn),
                        .i_w_load(i_w_load),
                        .i_acc_clear(i_acc_clear_pe), // need to handle this in fsm though gate eveyrthing during clear count dead?
                        .i_w    (weight_w[r][c]),
                        .o_w    (weight_w[r+1][c]),
                        .i_a    (act_w[r][c]),
                        .o_a    (act_w[r][c+1]),
                        .i_psum (psum_w[r][c]),
                        .o_psum (psum_w[r+1][c])
                );
            end
        end
    endgenerate

    // output deskew
    logic signed [pe_acc_w-1:0] c_deskew [pe_n]; // bottom edge psums
    generate
        for (genvar c = 0; c < pe_n; c = c+ 1) begin : gen_c_deskew
            localparam int delay = pe_n - 1 - c; // col n-1 0 delay (col 0 max delay)
            
            if (delay == 0) begin
                assign c_deskew[c] = psum_w[pe_n][c];
            end else begin
                logic signed [pe_acc_w-1:0] delay_r [delay:1];
                always_ff @(posedge clk or negedge rstn) begin
                    if(!rstn) begin
                        for (int i= 0; i <= delay; i++) begin
                            delay_r[i] <= '0;
                        end
                    end else begin
                        delay_r[1] <= psum_w[pe_n][c];
                        for (int i= 2; i<= delay; i= i+1) begin
                            delay_r[i] <= delay_r[i-1];
                        end
                    end
                end
                assign c_deskew[c] = delay_r[delay];
            end    
            assign o_c[c*pe_acc_w +: pe_acc_w] = c_deskew[c];
        end
    endgenerate
    
endmodule
`default_nettype wire
