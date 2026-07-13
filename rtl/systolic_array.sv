`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter MATRIX_SIZE = 2,
    parameter DATA_WIDTH = 8,
    parameter CSR_ADDR_W = 8,
    parameter STREAM_W = 32,
    parameter bit PERF_COUNTER_EN = 1'b0
)(
    input wire clk,
    input wire rstn,

    // csr config regs
    input wire csr_wr,
    input wire csr_rd,
    input wire [CSR_ADDR_W-1:0] csr_addr,
    input wire [31:0] csr_wdata,
    output wire [31:0] csr_rdata,
    output wire csr_rvalid,

    // input stream (a then b)
    input wire s_tvalid,
    output wire s_tready,
    input wire [STREAM_W-1:0] s_tdata,
    input wire s_tlast,

    // output stream (c in row-major)
    output wire m_tvalid,
    input wire m_tready,
    output wire [STREAM_W-1:0] m_tdata,
    output wire m_tlast
);
    localparam ARRAY_ROWS = MATRIX_SIZE;
    localparam ARRAY_COLS = MATRIX_SIZE;
    localparam MATRIX_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE;
    localparam INNER_DIM = MATRIX_SIZE; // K MACs per PE

    localparam FILL_CYCLES = (ARRAY_ROWS-1) + (ARRAY_COLS-1);
    localparam PE_LATENCY = 1;
    localparam TOTAL_COMPUTE_CYCLES = FILL_CYCLES + INNER_DIM + PE_LATENCY;
    localparam COUNT_WIDTH = $clog2(TOTAL_COMPUTE_CYCLES + 1);
    
    localparam RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE);
    localparam PE_ACC_WIDTH = RESULT_WIDTH;
    localparam DRAIN_IDX_W = $clog2(MATRIX_ELEMENTS);
    localparam PACKED_W = MATRIX_ELEMENTS * DATA_WIDTH;

    // CSR address map
    localparam logic [CSR_ADDR_W-1:0] ADDR_CTRL = 'h00;
    localparam logic [CSR_ADDR_W-1:0] ADDR_STATUS = 'h04;
    // localparam logic [CSR_ADDR_W-1:0] ADDR_CYCLES = 'h08;

    localparam CTRL_SIGNED_BIT = 1;
    localparam STATUS_BUSY_BIT = 0;
    localparam STATUS_STATE_LSB = 2;
    localparam STATUS_STATE_MSB = 4;

    typedef enum logic [2:0] {
        RECV_A = 3'd0, // idle cum receive a
        RECV_B = 3'd1,
        CLEAR = 3'd2,
        COMPUTE = 3'd3,
        DRAIN = 3'd4
    } state_t;
    state_t current_state, next_state;

    wire status_busy = (current_state != RECV_A);

    // stream handshakes
    wire slave_hs = s_tvalid && s_tready;
    wire master_hs = m_tvalid && m_tready;

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

    // drain index (result element on the bus)
    logic [DRAIN_IDX_W-1:0] drain_idx_r;
    wire drain_last = (drain_idx_r == DRAIN_IDX_W'(MATRIX_ELEMENTS-1));
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            drain_idx_r <= '0;
        end else if (current_state != DRAIN) begin
            drain_idx_r <= '0;
        end else if (master_hs) begin
            drain_idx_r <= drain_idx_r + DRAIN_IDX_W'(1);
        end
    end

    // next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            RECV_A:  begin
                if (slave_hs) begin
                    next_state = RECV_B;
                end
            end
            RECV_B: begin
                if (slave_hs) begin
                    next_state = CLEAR;
                end
            end
            CLEAR: next_state = COMPUTE;
            COMPUTE: begin
                if (compute_last) begin
                    next_state = DRAIN;
                end
            end
            DRAIN: begin
                if (drain_last && master_hs) begin
                     next_state = RECV_A;
                end
            end
            default: next_state = RECV_A; // base idle state
        endcase
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= RECV_A;
        end else begin
            current_state <= next_state;
        end
    end

    // input register file (operands)
    logic [PACKED_W-1:0] a_r, b_r; // storeing input matrix
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            a_r <= '0;
            b_r <= '0;
        end else begin
            if (current_state == RECV_A && slave_hs) begin
                a_r <= s_tdata[PACKED_W-1:0];// register input a 
            end
            
            if (current_state == RECV_B && slave_hs) begin
                b_r <= s_tdata[PACKED_W-1:0]; // registter input b
            end
        end
    end

    // signed control pe
    logic pe_ctrl_signed_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pe_ctrl_signed_r <= 1'b0;
        end else if (csr_wr && (csr_addr == ADDR_CTRL) && !status_busy) begin
            pe_ctrl_signed_r <= csr_wdata[CTRL_SIGNED_BIT];
        end
    end

    // perf counter (unneded i already do a performance counter forgot to remove it)
    // logic [31:0] run_cycles_r;
    // always_ff @(posedge clk or negedge rstn) begin
    //     if (!rstn) begin
    //         run_cycles_r <= 32'd0;
    //     end else if (current_state == RECV_A) begin
    //         run_cycles_r <= 32'd0;
    //     end else begin
    //         run_cycles_r <= run_cycles_r + 32'd1;
    //     end
    // end

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

    // feeding wires
    generate
        for (r = 0; r < ARRAY_ROWS; r= r + 1) begin : gen_a_feed
            wire [COUNT_WIDTH-1:0] elm_a = cycle_count_r - COUNT_WIDTH'(r); // element of row dot prod current cycle
            wire [COUNT_WIDTH-1:0] start = COUNT_WIDTH'(r);
            wire [COUNT_WIDTH-1:0] stop = COUNT_WIDTH'(r + INNER_DIM);
            // feed window true if 0 <= elm_a < k
            wire feed_window = (cycle_count_r >= start) && (cycle_count_r < stop); // check if row in feed window
            
            assign pe_a_in[r][0] = (pe_enable && feed_window) ? a_r[DATA_WIDTH*(INNER_DIM*r + elm_a) +: DATA_WIDTH] : '0;
        end
    endgenerate

    generate
        for (c = 0; c < ARRAY_COLS; c= c + 1) begin : gen_b_feed
            wire [COUNT_WIDTH-1:0] elm_b = cycle_count_r - COUNT_WIDTH'(c); // element of col dot prod current cycle
            wire [COUNT_WIDTH-1:0] start = COUNT_WIDTH'(c);
            wire [COUNT_WIDTH-1:0] stop = COUNT_WIDTH'(c + INNER_DIM);
            wire feed_window = (cycle_count_r >= start) && (cycle_count_r < stop); // check if col in feed window
            // feed window true if 0 <= elm_b < k

            assign pe_b_in[0][c] = (pe_enable && feed_window) ? b_r[DATA_WIDTH*(ARRAY_COLS*elm_b + c) +: DATA_WIDTH] : '0;
        end
    endgenerate

    // output stream drain the accumulators (no storage)
    wire [RESULT_WIDTH-1:0] drain_res = pe_result_flat[drain_idx_r];
    wire signed [RESULT_WIDTH-1:0] drain_res_s = drain_res;

    assign s_tready = (current_state == RECV_A) || (current_state == RECV_B);
    assign m_tvalid = (current_state == DRAIN);
    assign m_tlast = (current_state == DRAIN) && drain_last;
    assign m_tdata = pe_ctrl_signed_r ? 32'(drain_res_s) : 32'(drain_res);

    // csr control
    logic [31:0] ctrl_rdata;
    always_comb begin
        ctrl_rdata = 32'd0;
        case (csr_addr)
            ADDR_CTRL: ctrl_rdata[CTRL_SIGNED_BIT] = pe_ctrl_signed_r;
            ADDR_STATUS: begin
                ctrl_rdata[STATUS_BUSY_BIT] = status_busy;
                ctrl_rdata[STATUS_STATE_MSB:STATUS_STATE_LSB] = current_state;
            end
            // ADDR_CYCLES: ctrl_rdata = run_cycles_r;
            default: ctrl_rdata = 32'd0;
        endcase
    end

    logic rvalid_r;
    logic [31:0] ctrl_rdata_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rvalid_r <= 1'b0;
            ctrl_rdata_r <= 32'd0;
        end else begin
            rvalid_r <= csr_rd;
            ctrl_rdata_r <= ctrl_rdata;
        end
    end
    
    assign csr_rdata = ctrl_rdata_r;
    assign csr_rvalid = rvalid_r;

    // peroformance counter
    generate
        if (PERF_COUNTER_EN) begin : gen_perf_counters
            perf_monitor perf_inst (
                .clk         (clk),
                .rstn        (rstn),
                .i_run_start (current_state == RECV_B && slave_hs),
                .i_run_done  (current_state == DRAIN && drain_last && master_hs),
                .i_busy      (status_busy),
                .i_load      ((current_state == RECV_A) || (current_state == RECV_B)),
                .i_compute   (pe_enable),
                .i_writeback (current_state == DRAIN),
                .i_mem_access(1'b0),
                .i_csr_wr    (csr_wr),
                .i_csr_rd    (csr_rd)
            );
        end
    endgenerate

endmodule
`default_nettype wire
