`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter MATRIX_SIZE = 2,
    parameter DATA_WIDTH = 8,
    // parameter RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 17 (16+1 for overflow)
    parameter CSR_ADDR_W = 8
)(
    input logic clk,
    input logic rstn, 

    // csr strobe
    input logic csr_wr,
    input logic [CSR_ADDR_W-1:0] csr_addr,
    input logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata
);
    localparam ARRAY_ROWS = MATRIX_SIZE;
    localparam ARRAY_COLS = MATRIX_SIZE;
    localparam N_PES = ARRAY_ROWS * ARRAY_COLS;
    localparam INNER_DIM = MATRIX_SIZE; // K MACs per PE
    localparam FILL_CYCLES = (ARRAY_ROWS - 1) + (ARRAY_COLS - 1);  // 2
    localparam PE_LATENCY = 2;
    localparam TOTAL_COMPUTE_CYCLES = FILL_CYCLES + INNER_DIM + PE_LATENCY; // 6
    localparam TOTAL_DRAIN_CYCLES = 1;
    localparam COUNT_WIDTH = $clog2(TOTAL_COMPUTE_CYCLES + 1);
    localparam RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE); // 17 (16+1 for overflow)
    localparam PE_ACC_WIDTH = RESULT_WIDTH;

    // CSR address map
    localparam logic [CSR_ADDR_W-1:0] ADDR_CTRL = 'h00;
    localparam logic [CSR_ADDR_W-1:0] ADDR_STATUS = 'h04;
    localparam logic [CSR_ADDR_W-1:0] ADDR_CYCLES = 'h08;
    localparam logic [CSR_ADDR_W-1:0] ADDR_MATRIX_A = 'h10;
    localparam logic [CSR_ADDR_W-1:0] ADDR_MATRIX_B = 'h14;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RESULT_00 = 'h20;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RESULT_01 = 'h24;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RESULT_10 = 'h28;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RESULT_11 = 'h2C;

    // reserving these for later (irq stuff)
    // read 0 for now
    localparam logic [CSR_ADDR_W-1:0] ADDR_RES_0 = 'h0C;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RES_1 = 'h18;
    localparam logic [CSR_ADDR_W-1:0] ADDR_RES_2 = 'h1C;

    localparam CTRL_START_BIT = 0;
    localparam CTRL_SIGNED_BIT = 1;
    localparam CTRL_ABORT_BIT = 2;

    localparam STATUS_BUSY_BIT = 0;
    localparam STATUS_DONE_BIT= 1;
    localparam STATUS_STATE_LSB = 2; // [4:2]
    localparam STATUS_STATE_MSB = 4;

    typedef enum logic [2:0] {
        IDLE = 3'd0,
        CLEAR = 3'd1,
        COMPUTE = 3'd2, 
        DRAIN = 3'd3,
        DONE = 3'd4
    } state_t;
    state_t current_state, next_state;

    // CSR write decode
    wire csr_wr_ctrl = csr_wr && (csr_addr == ADDR_CTRL);
    wire csr_wr_status = csr_wr && (csr_addr == ADDR_STATUS);

    wire start_pulse = csr_wr_ctrl && csr_wdata[CTRL_START_BIT];
    wire abort_pulse = csr_wr_ctrl && csr_wdata[CTRL_ABORT_BIT];

    wire status_busy = (current_state != IDLE);
    wire done_set = (current_state == DRAIN) && (next_state == DONE);
    wire done_w1c = csr_wr_status && csr_wdata[STATUS_DONE_BIT]; // sticky
    
    // signed control pe
    logic pe_ctrl_signed_r; // note to self (check for its fanout during librelane flow)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pe_ctrl_signed_r <= 1'd0;
        end else if (csr_wr_ctrl) begin
            pe_ctrl_signed_r <= csr_wdata[CTRL_SIGNED_BIT];
        end
    end

    logic status_done;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            status_done <= 1'd0;
        end else if (done_set) begin
            status_done <= 1'd1;
        end else if (done_w1c) begin
            status_done <= 1'd0;
        end
    end

    // compute count increments on compute cycle
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

    logic [31:0] run_cycles_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            run_cycles_r<= 'd0;
        end else if (start_pulse) begin
            run_cycles_r <= 'd0;
        end else if (status_busy && (current_state != DONE)) begin
            run_cycles_r <= run_cycles_r + 'd1;
        end
    end

    // next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start_pulse) next_state = CLEAR;
            end
            
            CLEAR: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (compute_last) next_state = DRAIN;
            end

            DRAIN: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end
            
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

    // csr decoeder
    always_comb begin
        csr_rdata = 'd0;
        case (csr_addr)
            ADDR_CTRL: begin
                csr_rdata[CTRL_SIGNED_BIT] = pe_ctrl_signed_r;
            end

            ADDR_STATUS: begin
                csr_rdata[STATUS_BUSY_BIT] = status_busy;
                csr_rdata[STATUS_DONE_BIT] = status_done;
                csr_rdata[STATUS_STATE_LSB+2:STATUS_STATE_LSB] = current_state;
            end

            ADDR_CYCLES: begin
                csr_rdata = run_cycles_r;
            end

            ADDR_RES_0, ADDR_RES_1, ADDR_RES_2: begin
                csr_rdata = '0;
            end

            
            default: csr_rdata = 'd0;
        endcase
    end

    wire pe_clear, pe_enable;
    assign pe_clear = (current_state == CLEAR);
    assign pe_enable = (current_state == COMPUTE);

    
    wire [DATA_WIDTH-1:0] pe_a_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_b_in [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_a_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] pe_b_out [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire [RESULT_WIDTH-1:0]  pe_result [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];

    genvar r, c;
    generate
        for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_pe_row
            for (c = 0; c < ARRAY_COLS; c = c+1 ) begin : gen_pe_column
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (PE_ACC_WIDTH)
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
    

endmodule
`default_nettype wire
