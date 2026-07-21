`default_nettype none
`timescale 1ps/1ps

module top #(
    parameter int unsigned CSR_DATA_W = 32
)(
`ifdef USE_POWER_PINS
    inout VCCD1,
    inout VSSD1,
`endif
    input wire clk,
    input wire rstn,

    // spi slave mode 0, sclk up to clk/2
    input wire spi_sclk,
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

    // csr channel, control/status only
    wire csr_wr_w, csr_rd_w, csr_rvalid_w;
    wire [1:0] csr_sel_w;
    wire [CSR_DATA_W-1:0] csr_wdata_w, csr_rdata_w;

    // data channels, straight between the spi shifter and the fifos/pes
    wire a_valid_w, b_valid_w, c_pop_w, c_valid_w;
    wire [1:0] b_lane_w;
    wire [CSR_DATA_W-1:0] a_data_w, b_data_w, c_data_w;

    spi_if #(
        .CSR_DATA_W(CSR_DATA_W)
    ) u_spi (
        .clk         (clk),
        .rstn        (rstn_sync_w),
        .spi_sclk    (spi_sclk),
        .spi_cs_n    (spi_cs_n),
        .spi_mosi    (spi_mosi),
        .spi_miso    (spi_miso),
        .o_csr_wr    (csr_wr_w),
        .o_csr_rd    (csr_rd_w),
        .o_csr_sel   (csr_sel_w),
        .o_csr_wdata (csr_wdata_w),
        .i_csr_rdata (csr_rdata_w),
        .i_csr_rvalid(csr_rvalid_w),
        .o_a_valid   (a_valid_w),
        .o_a_data    (a_data_w),
        .o_b_valid   (b_valid_w),
        .o_b_lane    (b_lane_w),
        .o_b_data    (b_data_w),
        .o_c_pop     (c_pop_w),
        .i_c_data    (c_data_w),
        .i_c_valid   (c_valid_w)
    );

    matmul_accel #(
        .CSR_DATA_W(CSR_DATA_W)
    ) u_accel (
        `ifdef USE_POWER_PINS
        .VCCD1(VCCD1),
        .VSSD1(VSSD1),
        `endif
        .clk         (clk),
        .rstn        (rstn_sync_w),
        .i_csr_wr    (csr_wr_w),
        .i_csr_rd    (csr_rd_w),
        .i_csr_sel   (csr_sel_w),
        .i_csr_wdata (csr_wdata_w),
        .o_csr_rdata (csr_rdata_w),
        .o_csr_rvalid(csr_rvalid_w),
        .i_a_valid   (a_valid_w),
        .i_a_data    (a_data_w),
        .i_b_valid   (b_valid_w),
        .i_b_lane    (b_lane_w),
        .i_b_data    (b_data_w),
        .i_c_pop     (c_pop_w),
        .o_c_data    (c_data_w),
        .o_c_valid   (c_valid_w),
        .o_irq       (o_irq)
    );
endmodule
`default_nettype wire
