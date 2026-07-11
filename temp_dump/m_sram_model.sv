// SRAM buffers two srams two read ports for a dn b
module m_sram_model #(
    parameter p_addr_w = 0,
    parameter p_data_w = 0
)(
    input wire i_clk,
    input wire i_rstn,
    input wire i_csb,
    input wire i_web,
    input logic [p_addr_w-1:0] i_addr,
    input logic [p_data_w-1:0] i_din,
    output logic [p_data_w-1:0] o_dout
);
    logic [p_data_w-1:0] mem [2**p_addr_w];
    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_csb) begin
            if (!i_web) begin
                mem[i_addr] <= i_din;
            end else begin
                o_dout <= mem[i_addr];
            end
        end
    end

endmodule
