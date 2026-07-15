`default_nettype none
`timescale 1ps/1ps

module spi_csr_bridge #(
    parameter int unsigned CSR_ADDR_W = 8,
    parameter int unsigned CSR_DATA_W = 32
)(
    input wire clk,
    input wire rstn,
    input wire spi_sclk,
    input wire spi_cs_n,
    input wire spi_mosi,
    output wire spi_miso,

    // csr master
    output wire csr_wr,
    output wire csr_rd,
    output wire [CSR_ADDR_W-1:0] csr_addr,
    output wire [CSR_DATA_W-1:0] csr_wdata,
    input wire [CSR_DATA_W-1:0] csr_rdata,
    input wire csr_rvalid
);
    localparam int unsigned CMD_BITS = 8;
    localparam int unsigned HDR_BITS = CMD_BITS + CSR_ADDR_W;
    localparam int unsigned FRAME_BITS = HDR_BITS + CSR_DATA_W;
    localparam int unsigned BIT_CNT_W = $clog2(FRAME_BITS + 1);

    // 2ff synchronizers for the async spi pins
    logic [1:0] sclk_sync_r, cs_sync_r, mosi_sync_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            sclk_sync_r <= 2'b00;
            cs_sync_r <= 2'b11;
            mosi_sync_r <= 2'b00;
        end else begin
            sclk_sync_r <= {sclk_sync_r[0], spi_sclk};
            cs_sync_r   <= {cs_sync_r[0], spi_cs_n};
            mosi_sync_r <= {mosi_sync_r[0], spi_mosi};
        end
    end

    // sclk edge detect in the clk domain
    logic sclk_q;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            sclk_q <= 1'b0;
        end else begin
            sclk_q <= sclk_sync_r[1];
        end
    end

    wire selected = !cs_sync_r[1];
    wire sclk_rise = selected && sclk_sync_r[1] && !sclk_q;
    wire sclk_fall = selected && !sclk_sync_r[1] && sclk_q;

    // rx sample mosi on rising edges
    logic [BIT_CNT_W-1:0] bit_cnt_r;
    logic [CMD_BITS-1:0] cmd_r;
    logic [CSR_ADDR_W-1:0] addr_r;
    logic [CSR_DATA_W-1:0] wdata_r;

    wire in_cmd_phase = (bit_cnt_r < BIT_CNT_W'(CMD_BITS));
    wire in_addr_phase = (bit_cnt_r >= BIT_CNT_W'(CMD_BITS)) && (bit_cnt_r < BIT_CNT_W'(HDR_BITS));
    wire frame_open = (bit_cnt_r < BIT_CNT_W'(FRAME_BITS));

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            bit_cnt_r <= '0;
            cmd_r <= '0;
            addr_r <= '0;
            wdata_r <= '0;
        end else if (!selected) begin
            bit_cnt_r <= '0; // frame resync usingcs high
        end else if (sclk_rise && frame_open) begin
            bit_cnt_r <= bit_cnt_r + 1'b1;
            if (in_cmd_phase) begin
                cmd_r <= {cmd_r[CMD_BITS-2:0], mosi_sync_r[1]};
            end else if (in_addr_phase) begin
                addr_r <= {addr_r[CSR_ADDR_W-2:0], mosi_sync_r[1]};
            end else begin
                wdata_r <= {wdata_r[CSR_DATA_W-2:0], mosi_sync_r[1]};
            end
        end
    end

    wire cmd_is_wr = cmd_r[CMD_BITS-1]; // valid once the cmd byte in

    logic rd_req_r, wr_req_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rd_req_r <= 1'b0;
            wr_req_r <= 1'b0;
        end else begin
            rd_req_r <= sclk_rise && (bit_cnt_r == BIT_CNT_W'(HDR_BITS-1)) && !cmd_is_wr;
            wr_req_r <= sclk_rise && (bit_cnt_r == BIT_CNT_W'(FRAME_BITS-1)) && cmd_is_wr;
        end
    end

    // tx load rdata on rvalid present the msb and shift on data-phase
    logic [CSR_DATA_W-1:0] tx_shift_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tx_shift_r <= '0;
        end else if (csr_rvalid) begin
            tx_shift_r <= csr_rdata;
        end else if (sclk_fall && (bit_cnt_r > BIT_CNT_W'(HDR_BITS))) begin
            tx_shift_r <= {tx_shift_r[CSR_DATA_W-2:0], 1'b0};
        end
    end

    wire miso_en = selected && !cmd_is_wr && (bit_cnt_r >= BIT_CNT_W'(HDR_BITS));

    assign spi_miso  = miso_en ? tx_shift_r[CSR_DATA_W-1] : 1'b0;
    assign csr_rd    = rd_req_r;
    assign csr_wr    = wr_req_r;
    assign csr_addr  = addr_r;
    assign csr_wdata = wdata_r;

    // cmd bits 6:0 no use
    /* verilator lint_off UNUSEDSIGNAL */
    wire _unused = &{1'b0, cmd_r[CMD_BITS-2:0]};
    /* verilator lint_on UNUSEDSIGNAL */

endmodule
`default_nettype wire
