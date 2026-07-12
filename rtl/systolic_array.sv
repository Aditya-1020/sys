`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter MATRIX_SIZE = 2,
    parameter DATA_WIDTH = 8,
    parameter CSR_ADDR_W = 8, // 2 bit region + 6 bit offset (grws for N>4)
    parameter bit PERF_COUNTER_EN = 1'b0
)(
    input wire clk,
    input wire rstn, 

    // csr strobe
    input wire csr_wr,
    input wire csr_rd,
    input wire [CSR_ADDR_W-1:0] csr_addr,
    input wire [31:0] csr_wdata,
    output wire [31:0] csr_rdata,
    output wire csr_rvalid
);
    localparam ARRAY_ROWS = MATRIX_SIZE;
    localparam ARRAY_COLS = MATRIX_SIZE;
    localparam MATRIX_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE;
    localparam INNER_DIM = MATRIX_SIZE; // K MACs per PE

    localparam FILL_CYCLES = (ARRAY_ROWS-1) + (ARRAY_COLS-1);
    localparam PE_LATENCY = 2;
    localparam TOTAL_COMPUTE_CYCLES = FILL_CYCLES + INNER_DIM + PE_LATENCY;
    localparam COUNT_WIDTH = $clog2(TOTAL_COMPUTE_CYCLES + 1);
    
    localparam RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE); // 17 (16+1 for overflow)
    localparam PE_ACC_WIDTH = RESULT_WIDTH;
    localparam WB_COUNT_WIDTH = $clog2(MATRIX_ELEMENTS);
    
    // CSR address map
    // addr[7:6] selects region
    localparam logic [1:0] REGION_CTRL = 2'd0; // 0x00-0x3F ctrl/stat
    localparam logic [1:0] REGION_A = 2'd1; // 0x40-0x7F a matrix cache
    localparam logic [1:0] REGION_B = 2'd2; // 0x80-0xbF B matrix cache
    localparam logic [1:0] REGION_C = 2'd3; // 0xC0-0xFF results C bus

    localparam logic [CSR_ADDR_W-1:0] ADDR_CTRL = 'h00;
    localparam logic [CSR_ADDR_W-1:0] ADDR_STATUS = 'h04;
    localparam logic [CSR_ADDR_W-1:0] ADDR_CYCLES = 'h08;
    
    localparam CTRL_START_BIT = 0;
    localparam CTRL_SIGNED_BIT = 1;
    localparam CTRL_ABORT_BIT = 2;

    localparam STATUS_BUSY_BIT = 0;
    localparam STATUS_DONE_BIT= 1;
    localparam STATUS_STATE_LSB = 2;
    localparam STATUS_STATE_MSB = 4;

    localparam SRAM_ADDR_W = 8;
    localparam SRAM_DATA_W = 32;
    localparam SEG_OFFSET_W = 6;
    localparam logic [1:0] SEG_A = 2'd0;
    localparam logic [1:0] SEG_B = 2'd1;
    localparam logic [1:0] SEG_C = 2'd2;

    typedef enum logic [2:0] {
        IDLE = 3'd0,
        LOAD_A = 3'd1,
        LOAD_B = 3'd2,
        CLEAR = 3'd3,
        COMPUTE = 3'd4,
        WRITEBACK = 3'd5,
        DONE = 3'd6
    } state_t;
    state_t current_state, next_state;

    wire status_busy = (current_state != IDLE);
    wire engine_ownd = (current_state == WRITEBACK); // sram rw port owned

    // CSR write decode
    wire [1:0] csr_region = csr_addr[CSR_ADDR_W-1 -:2]; // = [7:6]
    wire region_ctrl = (csr_region == REGION_CTRL);

    wire csr_wr_ctrl = csr_wr && (csr_addr == ADDR_CTRL);
    wire csr_wr_status = csr_wr && (csr_addr == ADDR_STATUS);

    wire start_pulse = csr_wr_ctrl && csr_wdata[CTRL_START_BIT];
    wire abort_pulse = csr_wr_ctrl && csr_wdata[CTRL_ABORT_BIT];
    wire done_w1c = csr_wr_status && csr_wdata[STATUS_DONE_BIT]; // sticky

    wire cache_a_access = (csr_region == REGION_A) && (csr_wr|| csr_rd) && !status_busy;
    wire cache_b_access = (csr_region == REGION_B) && (csr_wr|| csr_rd) && !status_busy;
    wire cache_c_access = (csr_region == REGION_C) && csr_rd && !status_busy;

    wire bus_data_access = cache_a_access || cache_b_access || cache_c_access;
    wire bus_data_wr = (cache_a_access || cache_b_access) && csr_wr;
    wire bus_data_rd = (cache_c_access && csr_rd);
    
    // signed control pe
    logic pe_ctrl_signed_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pe_ctrl_signed_r <= 1'd0;
        end else if (csr_wr_ctrl && !status_busy) begin // lock if busy
            pe_ctrl_signed_r <= csr_wdata[CTRL_SIGNED_BIT];
        end
    end

    // done (sticky w1c)
    logic status_done_r;
    wire done_set = (current_state == WRITEBACK) && (next_state == DONE);
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            status_done_r <= 1'd0;
        end else if (done_set) begin
            status_done_r <= 1'd1;
        end else if (done_w1c) begin
            status_done_r <= 1'd0;
        end
    end

    // perf counter (11 at 2x2 = clear+ 6 compute + 4 writeback)
    logic [31:0] run_cycles_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            run_cycles_r <= 32'd0;
        end else if (start_pulse && !status_busy) begin
            run_cycles_r <= 32'd0;
        end else if (status_busy && (current_state != DONE)) begin
            run_cycles_r <= run_cycles_r + 32'd1;
        end
    end

    // compute phase counter
    logic [COUNT_WIDTH-1:0] cycle_count_r;
    wire compute_last = (cycle_count_r == COUNT_WIDTH'(TOTAL_COMPUTE_CYCLES-1));
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin 
            cycle_count_r <= '0;
        end else if (current_state != COMPUTE) begin
            cycle_count_r <= '0;
        end else begin
            cycle_count_r <= cycle_count_r + COUNT_WIDTH'(1);
        end
    end

    // writeback counter
    logic [WB_COUNT_WIDTH-1:0] wb_idx_r;
    wire wb_last = (wb_idx_r == WB_COUNT_WIDTH'(MATRIX_ELEMENTS-1));
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wb_idx_r <= '0;
        end else if (current_state != WRITEBACK) begin
            wb_idx_r <= '0;
        end else begin
            wb_idx_r <= wb_idx_r + WB_COUNT_WIDTH'(1);
        end
    end

    // next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start_pulse) begin 
                    next_state = LOAD_A;
                end
            end

            LOAD_A: next_state = LOAD_B;
            LOAD_B: next_state = CLEAR;
            CLEAR: next_state = COMPUTE;
            
            COMPUTE: begin
                if (compute_last) begin 
                    next_state = WRITEBACK;
                end
            end
            WRITEBACK: begin
                if (wb_last) begin
                    next_state = DONE;
                end
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
        if (abort_pulse) begin // overrides
            next_state = IDLE;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    wire pe_clear = (current_state == CLEAR);
    wire pe_enable = (current_state == COMPUTE);

    wire [DATA_WIDTH-1:0] pe_a_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_b_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_a_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_b_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [RESULT_WIDTH-1:0] pe_result [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [RESULT_WIDTH-1:0] pe_result_flat [0:MATRIX_ELEMENTS-1];
    
    genvar r, c;
    generate
        for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_pe_row
            for (c = 0; c < ARRAY_COLS; c = c+1 ) begin : gen_pe_column
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (PE_ACC_WIDTH) // passes 17 (pe takes 16 INTENIONAL)
                 ) pe (
                    .clk     (clk),
                    .rstn    (rstn),
                    .i_enable(pe_enable),
                    .i_clear (pe_clear),
                    .i_signed(pe_ctrl_signed_r),
                    .i_a     (pe_a_in[r][c]),
                    .i_b     (pe_b_in[r][c]),
                    .o_a     (pe_a_out[r][c]),
                    .o_b     (pe_b_out[r][c]),
                    .o_psum  (pe_result[r][c])
                );

                // a to right b to bottom
                if (c < ARRAY_COLS-1) begin : gen_a_flow
                    assign pe_a_in[r][c+1] = pe_a_out[r][c];
                end

                if (r < ARRAY_ROWS-1) begin : gen_b_flow
                    assign pe_b_in[r+1][c] = pe_b_out[r][c];
                end

                assign pe_result_flat[r*ARRAY_COLS + c] = pe_result[r][c];
            end
        end
    endgenerate

    wire [31:0] feed_dout;
    wire feed_active = (current_state == LOAD_A) || (current_state == LOAD_B);
    wire feed_csb = !feed_active;
    wire [1:0] feed_seg_sel = (current_state == LOAD_A) ? SEG_A : SEG_B;
    wire [SRAM_ADDR_W-1:0] feed_addr = {feed_seg_sel, {SEG_OFFSET_W{1'b0}}};

    logic [31:0] a_hold_r, b_hold_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            a_hold_r <= '0;
            b_hold_r <= '0;
        end else begin
            if (current_state == LOAD_B) begin
                a_hold_r <= feed_dout;
            end
            
            if (current_state == CLEAR) begin
                b_hold_r <= feed_dout;
            end
        end
    end

    // sram access
    wire [RESULT_WIDTH-1:0] wb_pe_result = pe_result_flat[wb_idx_r];
    wire signed [RESULT_WIDTH-1:0] wb_pe_result_signed = wb_pe_result;
    wire [31:0] wb_data = pe_ctrl_signed_r ? 32'(wb_pe_result_signed) : 32'(wb_pe_result);

    logic [1:0] bus_seg;
    always_comb begin
        bus_seg = SEG_A;
        case (csr_region)
            REGION_A: bus_seg = SEG_A;
            REGION_B: bus_seg = SEG_B;
            REGION_C: bus_seg = SEG_C;
            default: bus_seg = SEG_A;
        endcase
    end

    wire [SEG_OFFSET_W-1:0] csr_addr_segb_ext = SEG_OFFSET_W'(csr_addr[5:2]);
    wire [SEG_OFFSET_W-1:0] wb_idx_r_segb_ext = SEG_OFFSET_W'(wb_idx_r);
    wire [SRAM_ADDR_W-1:0] bus_word = {bus_seg, csr_addr_segb_ext};
    wire [SRAM_ADDR_W-1:0] engg_word = {SEG_C, wb_idx_r_segb_ext};

    // enggine owns rw during writebck
    wire [31:0] sram_dout;
    wire sram_csb = !engine_ownd && !bus_data_access;
    wire sram_web = !engine_ownd && !bus_data_wr;
    wire [SRAM_ADDR_W-1:0] sram_addr = engine_ownd ? engg_word : bus_word;
    wire [31:0] sram_din = engine_ownd ? wb_data : csr_wdata;

    sram_model #(
        .ADDR_WIDTH(SRAM_ADDR_W),
        .DATA_WIDTH(SRAM_DATA_W)
     ) sram_model (
        .clk    (clk),
        .rw_csb (sram_csb),
        .rw_web (sram_web),
        .rw_addr(sram_addr),
        .rw_din (sram_din),
        .rw_dout(sram_dout),
        .r_csb  (feed_csb),
        .r_addr (feed_addr),
        .r_dout (feed_dout)
    );


endmodule
`default_nettype wire
