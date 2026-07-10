`default_nettype none
`timescale 1ps/1ps

module systolic_array #(
    parameter MATRIX_SIZE = 2,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 32,
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
    localparam TOTAL_COMPUTE_CYCLES = FILL_CYCLES + INNER_DIM; // 4
    
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

    // CSR wr decode
    wire csr_wr_ctrl = csr_wr && (csr_addr == ADDR_CTRL);
    wire csr_wr_status = csr_wr && (csr_addr == ADDR_STATUS);

    wire start_pulse = csr_wr_ctrl && csr_wdata[CTRL_START_BIT];
    wire abort_pulse = csr_wr_ctrl && csr_wdata[CTRL_ABORT_BIT];


endmodule
`default_nettype wire
