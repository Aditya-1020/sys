// result store: drains the capture fifo to memory as one INCR burst
`default_nettype none
`timescale 1ps/1ps

module axi4_dma_wr #(
	parameter integer ROW_W = 32,
	parameter integer AXI_ADDR_W = 32,
	parameter integer BEATS = 16, // one result matrix
	parameter integer AXI_DATA_W = ROW_W,
	localparam integer CNT_W = $clog2(BEATS)
)(
	input wire clk,
	input wire rstn,
	// from axi csr
	/* verilator lint_off UNUSEDSIGNAL */
	input wire [AXI_ADDR_W-1:0] i_dst_addr,
	/* verilator lint_on UNUSEDSIGNAL */
	input wire i_start, // pulse
	output wire o_busy,
	output wire o_resp,
	output wire o_last_beat,
	output wire o_done,
	output wire o_err, // sticky

	// axi master write
	output wire [AXI_ADDR_W-1:0] o_m_awaddr,
	output wire o_m_awvalid,
	input wire i_m_awready,

	output wire [AXI_DATA_W-1:0] o_m_wdata,
	output wire o_m_wlast,
	output wire o_m_wvalid,
	input wire i_m_wready,

	input wire [1:0] i_m_bresp,
	input wire i_m_bvalid,
	output wire o_m_bready,

	// result fifo read side
	input wire i_fifo_valid,
	input wire [AXI_DATA_W-1:0] i_fifo_rdata,
	output wire o_fifo_rd
);
	// payload only rest const
	typedef struct packed {
		logic [AXI_DATA_W-1:0] data;
		logic last;
	} w_payload_t;

	typedef struct packed {
		logic [1:0] resp;
	} b_payload_t;

	typedef enum logic [1:0] {
		IDLE,
		ADDR,
		DATA
	} state_t;

	state_t current_state, next_state;
	wire idle_state = (current_state == IDLE);

	logic [CNT_W-1:0] beat_cnt_r;
	wire last_cnt = (beat_cnt_r == CNT_W'(BEATS-1));

	logic aw_valid_int, aw_ready_int;
	logic w_valid_int, w_ready_int;
	logic b_valid_int, b_ready_int;

	logic [AXI_ADDR_W-1:0] aw_data_int;
	w_payload_t w_data_int, w_data_out;
	b_payload_t b_data_int, b_data_out;

	assign aw_data_int = {i_dst_addr[AXI_ADDR_W-1:2], 2'b00};

	skid_buffer #(
		.N(AXI_ADDR_W)
	) skid_aw (
		.clk    (clk),
		.rstn   (rstn),
		.i_valid(aw_valid_int),
		.o_ready(aw_ready_int),
		.i_ready(i_m_awready),
		.o_valid(o_m_awvalid),
		.i_data (aw_data_int),
		.o_data (o_m_awaddr)
	);

	assign w_data_int.data = i_fifo_rdata;
	assign w_data_int.last = last_cnt;

	skid_buffer #(
		.N($bits(w_payload_t))
	) skid_w (
		.clk    (clk),
		.rstn   (rstn),
		.i_valid(w_valid_int),
		.o_ready(w_ready_int),
		.i_ready(i_m_wready),
		.o_valid(o_m_wvalid),
		.i_data (w_data_int),
		.o_data (w_data_out)
	);

	assign o_m_wdata = w_data_out.data;
	assign o_m_wlast = w_data_out.last;

	assign b_data_int.resp = i_m_bresp;

	skid_buffer #(
		.N($bits(b_payload_t))
	) skid_b (
		.clk    (clk),
		.rstn   (rstn),
		.i_valid(i_m_bvalid),
		.o_ready(o_m_bready),
		.i_ready(b_ready_int),
		.o_valid(b_valid_int),
		.i_data (b_data_int),
		.o_data (b_data_out)
	);

	assign aw_valid_int = (current_state == ADDR);
	assign w_valid_int = ((current_state == DATA) || (current_state == ADDR)) && i_fifo_valid;
	assign b_ready_int = 1'b1; // responses are drained as they land; no gate

	wire beat = w_valid_int && w_ready_int;
	wire last_beat = beat && last_cnt;
	wire resp_beat = b_valid_int;
	assign o_last_beat = last_beat;
	wire burst_start = (idle_state || last_beat) && i_start;

	assign o_fifo_rd = beat;
	assign o_busy = !idle_state;

	always_comb begin
		next_state = current_state;
		unique case (current_state)
			IDLE: begin
				if (i_start) begin
					next_state = ADDR;
				end
			end
			ADDR: begin
				if (aw_ready_int) begin // switch when aw buffered
					next_state = DATA;
				end
			end
			DATA: begin
				if (last_beat) begin
					if (i_start) begin
						next_state = ADDR; // another tile present
					end else begin
						next_state = IDLE;
					end
				end
			end
		endcase
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			current_state <= IDLE;
		end else begin
			current_state <= next_state;
		end
	end

	always_ff @(posedge clk) begin
		if (idle_state || last_beat) begin
			beat_cnt_r <= '0;
		end else if (beat) begin
			beat_cnt_r <= beat_cnt_r + 1'b1;
		end
	end

	logic done_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			done_r <= 1'b0;
		end else if (burst_start) begin
			done_r <= 1'b0;
		end else if (resp_beat) begin
			done_r <= 1'b1;
		end
	end
	assign o_done = done_r;
	assign o_resp = resp_beat;

	logic err_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			err_r <= 1'b0;
		end else if (burst_start) begin
			err_r <= 1'b0;
		end else if (resp_beat && (b_data_out.resp != 2'b00)) begin
			err_r <= 1'b1;
		end
	end
	assign o_err = err_r;

endmodule
`default_nettype wire
