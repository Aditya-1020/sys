`default_nettype none
`timescale 1ps/1ps

module matmul_accel #(
    parameter int unsigned CSR_ADDR_W = 8,
    parameter int unsigned CSR_DATA_W = 32
)(
    input wire clk,
    input wire rstn,

    // memory mapped register bus
    input wire csr_wr,
    input wire csr_rd,
    input wire [CSR_ADDR_W-1:0] csr_addr,
    input wire [CSR_DATA_W-1:0] csr_wdata,
    output wire [CSR_DATA_W-1:0] csr_rdata,
    output wire csr_rvalid,

    // completion interrupt to the cpu
    output wire o_irq
);
    localparam int unsigned MATRIX_SIZE = 4;
    localparam int unsigned DATA_WIDTH = 8;
    localparam int unsigned RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE);
    localparam int unsigned PACKED_W = MATRIX_SIZE * MATRIX_SIZE * DATA_WIDTH;
    localparam int unsigned MATRIX_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE;
    localparam int unsigned WORD_W = MATRIX_SIZE * DATA_WIDTH; // packed row = 32b

    localparam logic [CSR_ADDR_W-1:0] ADDR_CTRL = 'h00;
    localparam logic [CSR_ADDR_W-1:0] ADDR_STATUS = 'h04;
    localparam logic [CSR_ADDR_W-1:0] ADDR_CYCLES = 'h08;
    localparam logic [CSR_ADDR_W-1:0] ADDR_IRQ = 'h0C;

    localparam int CTRL_START_BIT = 0;
    localparam int CTRL_SIGNED_BIT = 1;
    localparam int CTRL_IRQ_EN_BIT = 2;
    localparam int STATUS_BUSY_BIT = 0;
    localparam int STATUS_DONE_BIT = 1;
    localparam int IRQ_DONE_BIT = 0;

    logic [PACKED_W-1:0] a_buf, b_buf;
    // capture raw result
    logic [RESULT_WIDTH-1:0] c_buf [0:MATRIX_ELEMENTS-1];

    // config status regs
    logic signed_r, irq_en_r, done_r;
    logic [CSR_DATA_W-1:0] cycles_r, cycles_cnt;

    typedef enum logic [1:0] {
        W_IDLE,
        W_ISSUE,
        W_WAIT
    } wstate_t;
    wstate_t current_wstate, next_wstate;

    wire busy = (current_wstate != W_IDLE);

    wire core_done;
    wire [MATRIX_ELEMENTS-1:0][RESULT_WIDTH-1:0] core_result_data;

    wire core_start = (current_wstate == W_ISSUE); // latch a/b and clear sticky done
    wire core_busy;
    /* verilator lint_off UNUSED */
    wire _unused = 1'b0 && &{1'b0, core_busy, 1'b0};
    /* verilator lint_on UNUSED */
    
    systolic_array #(
        .MATRIX_SIZE     (MATRIX_SIZE),
        .DATA_WIDTH      (DATA_WIDTH)
    ) core_inst (
        .clk           (clk),
        .rstn          (rstn),
        .i_ld_a        (a_buf),
        .i_ld_b        (b_buf),
        .i_pe_sign_en  (signed_r),
        .i_start       (core_start),
        .o_done        (core_done),
        .o_busy        (core_busy),
        .o_result_data (core_result_data)
    );

    // address decoder
    wire in_a = (csr_addr[7:4] == 4'h1);
    wire in_b = (csr_addr[7:4] == 4'h2);
    wire in_c = (csr_addr[7:6] == 2'b01);
    wire [1:0] ab_idx = csr_addr[3:2]; // a/ b row select 0-3
    wire [3:0] c_idx = csr_addr[5:2]; // c element select 0-15

    wire start_cmd = csr_wr && (csr_addr == ADDR_CTRL) && csr_wdata[CTRL_START_BIT] && !busy;
    wire result_taken = (current_wstate == W_WAIT) && core_done;

    // next state logic
    always_comb begin
        next_wstate = current_wstate;
        case (current_wstate)
            W_IDLE: begin
                if (start_cmd) begin
                    next_wstate = W_ISSUE;
                end
            end
            W_ISSUE: next_wstate = W_WAIT; // start pulse taken by the array
            W_WAIT: begin
                if (core_done) begin
                    next_wstate = W_IDLE; // sticky done after resultdata setttles
                end
            end
            default: next_wstate = W_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_wstate <= W_IDLE;
        end else begin
            current_wstate <= next_wstate;
        end
    end

    // config and operand write
    always_ff @(posedge clk or negedge rstn) begin
        if (csr_wr) begin
            if (in_a) begin
                a_buf[WORD_W*ab_idx +: WORD_W] <= csr_wdata[WORD_W-1:0];
            end
            if (in_b) begin
                b_buf[WORD_W*ab_idx +: WORD_W] <= csr_wdata[WORD_W-1:0];
            end
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
           signed_r <= 1'b0;
           irq_en_r <= 1'b0; 
        end else if (csr_wr && (csr_addr == ADDR_CTRL && !busy)) begin
            signed_r <= csr_wdata[CTRL_SIGNED_BIT];
            irq_en_r <= csr_wdata[CTRL_IRQ_EN_BIT];
        end
    end

    // count duration busy
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            cycles_cnt <= '0;
        end else if (current_wstate == W_IDLE) begin
            cycles_cnt <= '0;
        end else begin
            cycles_cnt <= cycles_cnt + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (result_taken) begin
            for (int unsigned i = 0; i < MATRIX_ELEMENTS; i++) begin
                c_buf[i]  <= core_result_data[i];
            end
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            cycles_r <= '0;
        end else if (result_taken) begin
            cycles_r <= cycles_cnt + 1'b1;
        end
    end
    
    logic done_n;
    always_comb begin
        done_n = done_r;
        if (csr_wr && (csr_addr == ADDR_IRQ) && csr_wdata[IRQ_DONE_BIT]) begin
            done_n = 1'b0;
        end else if (result_taken) begin
            done_n = 1'b1;
        end else if (start_cmd) begin
            done_n = 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            done_r <= 1'b0;
        end else begin
            done_r <= done_n;
        end
    end

    // read extension of the selected c word using the current signed mode
    localparam int unsigned RDATA_EXT_WIDTH = CSR_DATA_W - RESULT_WIDTH;
    wire [RESULT_WIDTH-1:0] c_word = c_buf[c_idx];
    wire c_ext_bit = signed_r && c_word[RESULT_WIDTH-1];
    wire [CSR_DATA_W-1:0] c_ext = {{RDATA_EXT_WIDTH{c_ext_bit}}, c_word};
    
    logic [CSR_DATA_W-1:0] rdata_c;
    always_comb begin
        rdata_c = '0;
        case (csr_addr)
            ADDR_CTRL: begin
                rdata_c[CTRL_SIGNED_BIT] = signed_r;
                rdata_c[CTRL_IRQ_EN_BIT] = irq_en_r;
            end
            ADDR_STATUS: begin
                rdata_c[STATUS_BUSY_BIT] = busy;
                rdata_c[STATUS_DONE_BIT] = done_r;
            end
            ADDR_CYCLES: rdata_c = cycles_r;
            ADDR_IRQ: rdata_c[IRQ_DONE_BIT] = done_r;
            default: begin
                if (in_c) begin
                    rdata_c = c_ext;
                end
            end
        endcase
    end

    logic rvalid_r;
    logic [CSR_DATA_W-1:0] rdata_r;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rvalid_r <= 1'b0;
            rdata_r  <= '0;
        end else begin
            rvalid_r <= csr_rd;
            rdata_r  <= rdata_c;
        end
    end

    assign csr_rdata  = rdata_r;
    assign csr_rvalid = rvalid_r;
    assign o_irq = irq_en_r && done_r;

endmodule
`default_nettype wire
