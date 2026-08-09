// memory mapped
`default_nettype none
`timescale 1ps/1ps

module axi4_dma #(
	parameter integer ROW_W = 32,
	parameter integer AXI_ADDR_W = 32,
	parameter integer SRAM_ADDR_W = 6,

	parameter integer AXI_DATA_W = ROW_W, // must eq ROW_W
	parameter integer LEN_W = SRAM_ADDR_W + 1
)(
	input wire clk,
	input wire rstn,

	// from axi csr
	/* verilator lint_off UNUSEDSIGNAL */
	input wire [AXI_ADDR_W-1:0] i_src_addr, // byte addr, [1:0] dropped (word aligned)
	/* verilator lint_on UNUSEDSIGNAL */
	input wire [LEN_W-1:0] i_len, // words to move into half
	input wire i_start, // pulse
	output wire o_busy,
	output wire o_done,
	output wire o_err, // sticky

	// axi master read, fetch
	output wire [AXI_ADDR_W-1:0] o_m_araddr,
	output wire [7:0] o_m_arlen,
	output wire o_m_arvalid,
	input wire i_m_arready,

	input wire [AXI_DATA_W-1:0] i_m_rdata,
	input wire [1:0] i_m_rresp,
	input wire i_m_rlast,
	input wire i_m_rvalid,
	output wire o_m_rready,

	// sram p0
	output wire o_dma_cs,
	output wire o_dma_we,
	output wire [3:0] o_dma_mask, // 4 byte lane
	output wire [SRAM_ADDR_W-1:0] o_dma_addr,
	output wire [ROW_W-1:0] o_dma_wdata,

	// ping pong owner
	output wire o_swap,
	output wire o_fill_done,
	input wire i_array_done
);
	assign o_dma_we = 1'b1;
	assign o_dma_mask = 4'hF; // full row
	assign o_dma_wdata = i_m_rdata;

	typedef enum logic [1:0] {
		IDLE,
		ADDR,
		DATA,
		FILL
	} state_t;
	state_t current_state, next_state;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			current_state <= IDLE;
		end else begin
			current_state <= next_state;
		end
	end

	wire idle_state = (current_state == IDLE);

	assign o_m_arvalid = (current_state == ADDR);
	assign o_m_rready = (current_state == DATA); // no sram backpressure
	assign o_dma_cs = i_m_rvalid && o_m_rready;

	wire beat = o_dma_cs;
	wire last_beat = beat && i_m_rlast;

	wire [10:0] burst_end_w = {1'b0, i_src_addr[11:2]} + 11'(i_len);
	wire desc_bad = (i_len == '0) || (i_len > LEN_W'(1 << SRAM_ADDR_W)) || (burst_end_w > 11'd1024);

	always_comb begin
		next_state = current_state;
		unique case (current_state)
			IDLE: begin
				if (i_start && !desc_bad) begin
					next_state = ADDR;
				end
			end
			ADDR: begin
				if (i_m_arready) begin
					next_state = DATA;
				end
			end
			DATA: begin
				if (last_beat) begin
					next_state = FILL;
				end
			end
			FILL: begin
				if (i_array_done) begin
					next_state = IDLE;
				end
			end
		endcase
	end

	localparam integer ARLEN_W = LEN_W + 1;

	logic [ARLEN_W-1:0] arlen_r;
	always_ff @(posedge clk) begin
		if (idle_state && i_start) begin
			arlen_r <= {1'b0, i_len} - 1'b1;
		end
	end

	assign o_m_araddr = {i_src_addr[AXI_ADDR_W-1:2], 2'b00};
	assign o_m_arlen = arlen_r;

	logic [SRAM_ADDR_W-1:0] wr_ptr_r;
	assign o_dma_addr = wr_ptr_r;

	always_ff @(posedge clk) begin
		if (idle_state && i_start) begin
			wr_ptr_r <= '0;
		end else if (beat) begin
			wr_ptr_r <= wr_ptr_r + 1'b1;
		end
	end

	wire expected_last = (arlen_r == ARLEN_W'(wr_ptr_r));
	wire len_mismatch = beat && (i_m_rlast != expected_last);

	assign o_busy = !idle_state;

	logic done_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			done_r <= 1'b0;
		end else if (idle_state && i_start) begin
			done_r <= 1'b0;
		end else if (last_beat) begin
			done_r <= 1'b1;
		end
	end
	assign o_done = done_r;

	logic err_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			err_r <= 1'b0;
		end else if (idle_state && i_start && desc_bad) begin
			err_r <= 1'b1;
		end else if (idle_state && i_start) begin
			err_r <= 1'b0;
		end else if ((beat && (i_m_rresp != 2'b00)) || len_mismatch) begin
			err_r <= 1'b1;
		end
	end
	assign o_err = err_r;

	assign o_fill_done = (current_state == FILL);
	assign o_swap = (current_state == FILL) && i_array_done;

endmodule
`default_nettype wire

