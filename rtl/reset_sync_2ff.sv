`default_nettype none
`timescale 1ps/1ps
module reset_sync_2ff (
    input logic i_clk,
    input logic rstn_src,   // asynchronous active-low reset
    output logic rstn_sync
);
    logic [1:0] sync_reg;

    always_ff @(posedge i_clk or negedge rstn_src) begin
        if (!rstn_src)
            sync_reg <= 2'b00;
        else
            sync_reg <= {sync_reg[0], 1'b1};
    end

    assign rstn_sync = sync_reg[1];

endmodule
`default_nettype wire
