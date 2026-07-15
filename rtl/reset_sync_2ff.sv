`default_nettype none
`timescale 1ps/1ps
module reset_sync_2ff (
    input wire i_clk,
    input wire rstn_src,   // asynchronous active-low reset
    output wire rstn_sync
);
    logic [1:0] sync_reg;

    always_ff @(posedge i_clk or negedge rstn_src) begin
        if (!rstn_src) begin
            sync_reg <= 2'b00;
        end else begin
            sync_reg <= {sync_reg[0], 1'b1};
        end
    end

    assign rstn_sync = sync_reg[1];

endmodule
`default_nettype wire
