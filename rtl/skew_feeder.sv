// Triangular skew feeder
// delays activation, acc_en, acc_rst by i*PE_LATENCY
`default_nettype none
`timescale 1ps/1ps

module skew_feeder #(
    parameter int unsigned N = 2,
    parameter int unsigned XLEN = 8,
    parameter int unsigned PE_LATENCY = 3 // match pe.sv interal
)(
    input wire clk,
    input wire rstn,
    input wire acc_en_i, // from fsm
    input wire acc_rst_i, // from fsm
    input  wire signed [XLEN-1:0] input_row_i [N],
    output logic acc_en_o [N],
    output logic acc_rst_o [N],
    output logic signed [XLEN-1:0] input_row_o [N]
);
    // Row 0
    assign acc_en_o[0] = acc_en_i;
    assign acc_rst_o[0] = acc_rst_i;
    assign input_row_o[0] = input_row_i[0];

    for (genvar r = 1; r < N; r++) begin : g_row
        localparam int unsigned DEPTH = r * PE_LATENCY;
        
        // control shift
        logic [DEPTH-1:0] en_pipe_r;
        logic [DEPTH-1:0] rst_pipe_r;

        // activation shift register
        logic signed [XLEN-1:0] act_pipe_r [DEPTH];

        always_ff @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                en_pipe_r  <= '0;
                rst_pipe_r <= '0;
            end else begin
                en_pipe_r <= DEPTH'({en_pipe_r,  acc_en_i});
                rst_pipe_r <= DEPTH'({rst_pipe_r, acc_rst_i});
            end
        end

        always_ff @(posedge clk) begin
            act_pipe_r[0] <= input_row_i[r];
            for (int unsigned k = 1; k < DEPTH; k++) begin
                act_pipe_r[k] <= act_pipe_r[k-1];
            end
        end

        assign acc_en_o[r] = en_pipe_r[DEPTH-1];
        assign acc_rst_o[r] = rst_pipe_r[DEPTH-1];
        assign input_row_o[r] = act_pipe_r[DEPTH-1];
    end

endmodule
`default_nettype wire
