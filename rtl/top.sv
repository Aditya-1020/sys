`default_nettype none
`timescale 1ps/1ps

module top #(
    parameter int unsigned CSR_ADDR_W = 8,
    parameter int unsigned CSR_DATA_W = 32
)(
    input wire clk,
    input wire rstn,

    // spi slave mode 0 
    input wire spi_sclk, // clk/8
    input wire spi_cs_n,
    input wire spi_mosi,
    output wire spi_miso,

    output wire o_irq
);
    wire rstn_sync_w;
    reset_sync_2ff u_reset_sync (
        .i_clk    (clk),
        .rstn_src (rstn),
        .rstn_sync(rstn_sync_w)
    );

    wire csr_wr, csr_rd, csr_rvalid;
    wire [CSR_ADDR_W-1:0] csr_addr;
    wire [CSR_DATA_W-1:0] csr_wdata, csr_rdata;

    spi_csr_bridge #(
        .CSR_ADDR_W(CSR_ADDR_W),
        .CSR_DATA_W(CSR_DATA_W)
    ) u_bridge (
        .clk       (clk),
        .rstn      (rstn_sync_w),
        .spi_sclk  (spi_sclk),
        .spi_cs_n  (spi_cs_n),
        .spi_mosi  (spi_mosi),
        .spi_miso  (spi_miso),
        .csr_wr    (csr_wr),
        .csr_rd    (csr_rd),
        .csr_addr  (csr_addr),
        .csr_wdata (csr_wdata),
        .csr_rdata (csr_rdata),
        .csr_rvalid(csr_rvalid)
    );

    matmul_accel #(
        .CSR_ADDR_W(CSR_ADDR_W),
        .CSR_DATA_W(CSR_DATA_W)
    ) u_accel (
        .clk       (clk),
        .rstn      (rstn_sync_w),
        .csr_wr    (csr_wr),
        .csr_rd    (csr_rd),
        .csr_addr  (csr_addr),
        .csr_wdata (csr_wdata),
        .csr_rdata (csr_rdata),
        .csr_rvalid(csr_rvalid),
        .o_irq     (o_irq)
    );
endmodule
`default_nettype wire
