`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter MATRIX_SIZE = 2,
    parameter DATA_WIDTH = 8,
    parameter CSR_ADDR_W = 8 // 2 bit region + 6 bit offset (grws for N>4)
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

    localparam CACHE_WORDS_AB = (MATRIX_ELEMENTS*DATA_WIDTH + 31); // 32 (1 at 2x2)
    localparam CACHE_WORDS_C = MATRIX_ELEMENTS;
    localparam WB_COUNT_WIDTH = $clog2(MATRIX_ELEMENTS);

    localparam logic [1:0] REGION_CTRL = 2'b00;
    localparam logic [1:0] REGION_A = 2'b01;
    localparam logic [1:0] REGION_B = 2'b10;
    localparam logic [1:0] REGION_C = 2'b11;
    
    // CSR address map
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

    localparam logic [1:0] SEG_A = 2'd0;
    localparam logic [1:0] SEG_B = 2'd1;
    localparam logic [1:0] SEG_C = 2'd2;

    typedef enum logic [2:0] {
        IDLE = 3'd0,
        CLEAR = 3'd1,
        COMPUTE = 3'd2, 
        WRITEBACK = 3'd3,
        DONE = 3'd4
    } state_t;
    state_t current_state, next_state;

    // CSR write decode
    wire [1:0] region_w = csr_addr[CSR_ADDR_W-1 -: 2];
    wire region_ctrl = (region_w == REGION_CTRL);
    wire region_data = !region_ctrl;

    wire csr_wr_ctrl = csr_wr && (csr_addr == ADDR_CTRL);
    wire csr_wr_status = csr_wr && (csr_addr == ADDR_STATUS);

    wire start_pulse = csr_wr_ctrl && csr_wdata[CTRL_START_BIT];
    wire abort_pulse = csr_wr_ctrl && csr_wdata[CTRL_ABORT_BIT];

    wire status_busy = (current_state != IDLE);
    wire done_set = (current_state == WRITEBACK) && (next_state == DONE);
    wire done_w1c = csr_wr_status && csr_wdata[STATUS_DONE_BIT]; // sticky
    
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
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            status_done_r <= 1'd0;
        end else if (done_set) begin
            status_done_r <= 1'd1;
        end else if (done_w1c) begin
            status_done_r <= 1'd0;
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

    // perf counter (11 at 2x2 = clear+ 6 compute + 4 writeback)
    logic [31:0] run_cycles_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            run_cycles_r <= 32'd0;
        end else if (start_pulse) begin
            run_cycles_r <= 32'd0;
        end else if (status_busy && (current_state != DONE)) begin
            run_cycles_r <= run_cycles_r + 32'd1;
        end
    end

    // next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start_pulse) begin 
                    next_state = CLEAR;
                end
            end
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
    genvar r, c;

    wire [DATA_WIDTH-1:0] pe_a_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_b_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_a_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_b_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [RESULT_WIDTH-1:0] pe_result [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];

    // connections
    // left to right
    generate
        for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_row_a
            for (c = 0; c < ARRAY_COLS-1; c = c+1) begin : gen_col_b
               assign pe_a_in[r][c+1] = pe_a_out[r][c];
            end
        end
    endgenerate
    
    // top to bottom
    generate
        for (c =0; c < ARRAY_COLS; c= c + 1) begin : gen_col_b
            for (r = 0; r < ARRAY_ROWS-1; r = r + 1) begin : gen_row_b
                assign pe_b_in[r+1][c] = pe_b_out[r][c];
            end
        end
    endgenerate

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
            end
        end
    endgenerate

    wire [RESULT_WIDTH-1:0] result_flat [0:MATRIX_ELEMENTS-1];
    generate
        for (r = 0; r < ARRAY_ROWS;r= r+ 1) begin
            for (c = 0; c < ARRAY_COLS; c= c + 1) begin
                assign result_flat[r*ARRAY_COLS + c] = pe_result[r][c];
            end
        end
    endgenerate

    // input feeders


    wire [RESULT_WIDTH-1:0] wb_el = result_flat[wb_idx_r];
    wire [31:0] wb_data = pe_ctrl_signed_r ? 32'(signed'(wb_el)) : 32'(wb_el);

    wire engg_own = (current_state == WRITEBACK);
    wire bus_data_wr = csr_wr && ((region_w == REGION_A) || (region_w == REGION_B));
    wire bus_data_rd = csr_rd && region_data;
    wire bus_data_access =(bus_data_wr || bus_data_rd) && !engg_own;

    logic [1:0] bus_seg;
    always_comb begin
        bus_seg = SEG_A;
        case (region_w)
            REGION_A: bus_seg = SEG_A;
            REGION_B: bus_seg = SEG_B;
            REGION_C: bus_seg = SEG_C;
            default: bus_seg = SEG_A;
        endcase
    end

    wire [7:0] bus_word = {bus_seg, 2'b00, csr_addr[5:2]};
    wire [7:0] eng_word = {SEG_C,  {(6-WB_COUNT_WIDTH){1'b0}}, wb_idx_r};

    wire [31:0] sram_dout, feed_dout;
    wire sram_csb = engg_own ? 1'b0 : !bus_data_access;
    wire sram_web = engg_own ? 1'b0 : !bus_data_wr;
    wire [7:0] sram_addr = engg_own ? eng_word : bus_word;
    wire [31:0] sram_din = engg_own ? wb_data : csr_wdata;
    wire feed_csb = 1'b1; // deselected
    wire[7:0] feed_addr = '0;

    sram_model #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (32)
    ) sram (
        .clk     (clk),
        .rw_csb  (sram_csb),
        .rw_web  (sram_web),
        .rw_addr (sram_addr),
        .rw_din  (sram_din),
        .rw_dout (sram_dout),
        .r_csb   (feed_csb),
        .r_addr  (feed_addr),
        .r_dout  (feed_dout)
    );

    // csr decoder
    logic [31:0] ctrl_rdata;
    always_comb begin
        ctrl_rdata = '0;
        case (csr_addr)
            ADDR_CTRL: ctrl_rdata[CTRL_SIGNED_BIT] = pe_ctrl_signed_r;
            ADDR_STATUS: begin
                ctrl_rdata[STATUS_BUSY_BIT] = status_busy;
                ctrl_rdata[STATUS_DONE_BIT] = status_done_r;
                ctrl_rdata[STATUS_STATE_MSB:STATUS_STATE_LSB] = current_state;
            end
            ADDR_CYCLES: ctrl_rdata = run_cycles_r;
            default: ctrl_rdata = 32'd0;
        endcase
    end

    logic rvalid_r, rd_sram_inst_r;
    logic [31:0] ctrl_rdata_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rvalid_r <= '0;
            rd_sram_inst_r <= '0;
            ctrl_rdata_r <= 32'd0;
        end else begin
            rvalid_r <= csr_rd;
            rd_sram_inst_r <= bus_data_rd && !engg_own;
            ctrl_rdata_r <= region_ctrl ? ctrl_rdata : 32'd0;
        end
    end

    assign csr_rdata = rd_sram_inst_r ? sram_dout : ctrl_rdata_r;
    assign csr_rvalid = rvalid_r;

endmodule
`default_nettype wire
