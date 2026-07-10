`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter MATRIX_SIZE = 2,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE), // 17
    parameter CSR_ADDR_W = 8
)(
    input logic clk,
    input logic rstn, 

    // csr strobe
    input logic csr_wr,
    input logic [CSR_ADDR_W-1:0] csr_addr,
    input logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata,

    input logic [MATRIX_SIZE*DATA_WIDTH-1:0] i_a_feed, // col for a inputs
    input logic [MATRIX_SIZE*DATA_WIDTH-1:0] i_b_feed, // row for b inputs
    output logic [MATRIX_SIZE*MATRIX_SIZE*RESULT_WIDTH-1:0] o_result,
    output logic o_result_valid
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

    // CSR address map
    localparam ADDR_CTRL = 'h00;
    localparam ADDR_STATUS = 'h04;
    localparam ADDR_CYCLES = 'h08;

    localparam CTRL_START_BIT = 0;
    localparam CTRL_SIGNED_BIT = 1;
    localparam CTRL_ABORT_BIT = 2;

    localparam STATUS_BUSY_BIT = 0;
    localparam STATUS_DONE_BIT= 1;
    localparam STATUS_STATE_LSB = 2; // [4:2]

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

    logic done_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            done_r <= 1'd0;
        end else if (done_set) begin
            done_r <= 1'd1;
        end else if (done_w1c) begin
            done_r <= 1'd0;
        end
    end

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


    // next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start_pulse) next_state <= CLEAR;
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


    
endmodule
`default_nettype wire
