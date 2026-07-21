`default_nettype none
`timescale 1ps/1ps

module ctrl_unit #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	parameter integer CSR_DATA_W = 32,
	parameter integer ROW_W = MATRIX_SIZE * DATA_WIDTH, // 32
	parameter integer MAT_W = MATRIX_SIZE * ROW_W // 128
)(
	input wire clk,
	input wire rstn,
	
	// csr channel from spi_if, single cycle strobes
	input wire i_csr_wr,
	input wire i_csr_rd,
	input wire [1:0] i_csr_sel,
	input wire [CSR_DATA_W-1:0] i_csr_wdata,
	output logic [CSR_DATA_W-1:0] o_csr_rdata,
	output logic o_csr_rvalid,

	input wire i_b_valid,
	output logic o_b_en,

	input wire i_a_valid,
	input wire i_a_ready,

	// in_fifo
	input wire i_matrix_valid,
	input wire [MAT_W-1:0] i_matrix_data,
	output logic o_matrix_ready, // pop result

	// array
	output logic o_a_valid,
	output logic [ROW_W-1:0] o_a_row,
	output logic o_start,
	input wire i_array_busy,
	input wire i_array_done, // sticky; cleared on start
	input wire i_array_res_valid, // high through the result stream

	// status
	input wire i_in_empty,
	input wire i_in_full,
	input wire [7:0] i_in_level,
	input wire i_res_valid,
	input wire [7:0] i_res_level,

	output logic o_irq // high when array has result_ready
);
	localparam integer ROW_CNT_W = $clog2(MATRIX_SIZE);

	localparam logic [1:0] SEL_CTRL = 2'd0;
	localparam logic [1:0] SEL_STATUS = 2'd1;
	localparam logic [1:0] SEL_IRQ = 2'd2;

	localparam integer CTRL_EN = 0;
	localparam integer CTRL_IRQ_EN = 1;

	typedef enum logic [1:0] {
		IDLE,
		LOAD, // MATRIX_SIZE row beats
		START, // start pulse + pop
		RUN // wait done
	} state_t;
	state_t current_state, next_state;

	logic [1:0] ctrl_r;
	wire en = ctrl_r[CTRL_EN];

	logic [ROW_CNT_W-1:0] row_cnt_r;
	wire row_last = (row_cnt_r == ROW_CNT_W'(MATRIX_SIZE-1));
	wire launch = en && i_matrix_valid && !i_array_busy;

	always_comb begin
		next_state = current_state;
		case (current_state)
			IDLE: begin
				if (launch) begin
					next_state = LOAD;
				end
			end
			LOAD: begin
				if (row_last) begin
					next_state = START;
				end
			end
			START: next_state = RUN;
			RUN: begin
				if (i_array_done) begin
					next_state = IDLE;
				end
			end
			default: next_state = IDLE;
		endcase
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			current_state <= IDLE;
		end else begin
			current_state <= next_state;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			row_cnt_r <= '0;
		end else if (current_state != LOAD) begin
			row_cnt_r <= '0;
		end else begin
			row_cnt_r <= row_cnt_r + 1'b1;
		end
	end

	wire busy = (current_state != IDLE) || i_array_busy;

	assign o_a_valid = (current_state == LOAD);
	assign o_a_row = i_matrix_data[ROW_W*row_cnt_r +: ROW_W];
	assign o_start = (current_state == START);
	assign o_matrix_ready = (current_state == START);
	assign o_b_en = i_b_valid && !busy;

	wire csr_wr = i_csr_wr;
	wire csr_rd = i_csr_rd;
	wire ctrl_wr = csr_wr && (i_csr_sel == SEL_CTRL);
	wire irq_wr = csr_wr && (i_csr_sel == SEL_IRQ);

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			ctrl_r <= '0;
		end else if (ctrl_wr) begin
			ctrl_r <= i_csr_wdata[1:0];
		end
	end

	logic stream_q;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			stream_q <= 1'b0;
		end else begin
			stream_q <= i_array_res_valid;
		end
	end
	wire results_ready = i_array_res_valid && !stream_q;

	// sticky irq; set beats w1c
	logic irq_r, next_irq;
	always_comb begin
		next_irq = irq_r;
		if (irq_wr && i_csr_wdata[0]) begin
			next_irq = 1'b0;
		end
		if (results_ready) begin
			next_irq = 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			irq_r <= 1'b0;
		end else begin
			irq_r <= next_irq;
		end
	end

	// sticky a overflow
	logic a_ovfl_r, next_a_ovfl;
	always_comb begin
		next_a_ovfl = a_ovfl_r;
		if (irq_wr && i_csr_wdata[1]) begin
			next_a_ovfl = 1'b0;
		end
		if (i_a_valid && !i_a_ready) begin
			next_a_ovfl = 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			a_ovfl_r <= 1'b0;
		end else begin
			a_ovfl_r <= next_a_ovfl;
		end
	end

	// read
	logic [CSR_DATA_W-1:0] status_w;
	assign status_w = {8'h0, i_res_level, i_in_level, 3'h0, i_res_valid, i_array_done, i_in_full, i_in_empty, busy};

	logic [CSR_DATA_W-1:0] rdata_r, next_rdata;
	always_comb begin
		next_rdata = '0;
		if (i_csr_sel == SEL_CTRL) begin
			next_rdata = {30'h0, ctrl_r};
		end else if (i_csr_sel == SEL_STATUS) begin
			next_rdata = status_w;
		end else if (i_csr_sel == SEL_IRQ) begin
			next_rdata = {30'h0, a_ovfl_r, irq_r};
		end else begin
			next_rdata = '0;
		end
	end

	logic rvalid_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rdata_r <= '0;
			rvalid_r <= 1'b0;
		end else begin
			rvalid_r <= csr_rd;
			if (csr_rd) begin
				rdata_r <= next_rdata;
			end
		end
	end

	assign o_csr_rdata = rdata_r;
	assign o_csr_rvalid = rvalid_r;
	assign o_irq = irq_r && ctrl_r[CTRL_IRQ_EN];

endmodule
`default_nettype wire
