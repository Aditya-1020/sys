`default_nettype wire
`timescale 1ps/1ps

module spi_if #(
	parameter int unsigned CSR_DATA_W = 32
)(
	input wire clk,
	input wire rstn,

	input wire spi_sclk,
	input wire spi_cs_n,
	input wire spi_mosi,
	output wire spi_miso,

	// csr channel, control/status only
	output logic o_csr_wr,
	output logic o_csr_rd,
	output logic [1:0] o_csr_sel,
	output logic [CSR_DATA_W-1:0] o_csr_wdata,
	input wire [CSR_DATA_W-1:0] i_csr_rdata,
	input wire i_csr_rvalid,

	// a stream channel -> in_fifo
	output logic o_a_valid,
	output logic [CSR_DATA_W-1:0] o_a_data,

	// b weight channel -> array lanes
	output logic o_b_valid,
	output logic [1:0] o_b_lane,
	output logic [CSR_DATA_W-1:0] o_b_data,

	// c result channel <- out_fifo, 32b sign extended by the accel
	output logic o_c_pop,
	input wire [CSR_DATA_W-1:0] i_c_data,
	input wire i_c_valid
);
	typedef enum logic [1:0] {
		PH_CMD  = 2'd0, // 8 command bits
		PH_TURN = 2'd1, // 8 dead bits on reads, covers the fetch round trip
		PH_DATA = 2'd2  // 32b words until cs_n rises
	} phase_t;

	wire frame_rst = spi_cs_n | ~rstn;

	phase_t phase_r;
	logic [4:0] bit_r;
	logic [30:0] rx_shift_r;
	logic [7:0] cmd_r;
	logic [CSR_DATA_W-1:0] rx_word_r;
	logic cmd_tgl_r, rx_tgl_r, txw_tgl_r;

	wire [4:0] phase_last = (phase_r == PH_DATA) ? 5'd31 : 5'd7;
	wire bit_last = (bit_r == phase_last);

	always_ff @(posedge spi_sclk or posedge frame_rst) begin
		if (frame_rst) begin
			phase_r <= PH_CMD;
			bit_r <= '0;
		end else begin
			bit_r <= bit_last ? '0 : bit_r + 1'b1;
			if (bit_last) begin
				case (phase_r)
					// cmd bit 7 set = write; clear = read
					PH_CMD: phase_r <= rx_shift_r[6] ? PH_DATA : PH_TURN;
					PH_TURN: phase_r <= PH_DATA;
					default: phase_r <= phase_r;
				endcase
			end
		end
	end

	always_ff @(posedge spi_sclk or negedge rstn) begin
		if (!rstn) begin
			rx_shift_r <= '0;
			cmd_r <= '0;
			rx_word_r <= '0;
			cmd_tgl_r <= 1'b0;
			rx_tgl_r <= 1'b0;
			txw_tgl_r <= 1'b0;
		end else if (!spi_cs_n) begin
			rx_shift_r <= {rx_shift_r[29:0], spi_mosi};
			if ((phase_r == PH_CMD) && bit_last) begin
				cmd_r <= {rx_shift_r[6:0], spi_mosi};
				cmd_tgl_r <= ~cmd_tgl_r;
			end
			if ((phase_r == PH_DATA) && bit_last && cmd_r[7]) begin
				rx_word_r <= {rx_shift_r, spi_mosi};
				rx_tgl_r <= ~rx_tgl_r;
			end
			if ((phase_r == PH_DATA) && (bit_r == 5'd0) && !cmd_r[7]) begin
				txw_tgl_r <= ~txw_tgl_r;
			end
		end
	end

	logic [CSR_DATA_W-1:0] tx_word_r;
	logic [CSR_DATA_W-1:0] tx_shift_r;
	always_ff @(negedge spi_sclk or posedge frame_rst) begin
		if (frame_rst) begin
			tx_shift_r <= '0;
		end else if ((phase_r == PH_DATA) && !cmd_r[7]) begin
			tx_shift_r <= (bit_r == 5'd0) ? tx_word_r : {tx_shift_r[CSR_DATA_W-2:0], 1'b0};
		end
	end

	assign spi_miso = (!spi_cs_n && (phase_r == PH_DATA) && !cmd_r[7]) ? tx_shift_r[CSR_DATA_W-1] : 1'b0;

	logic [2:0] cmd_sync_r, rx_sync_r, txw_sync_r;
	logic [1:0] cs_sync_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			cmd_sync_r <= '0;
			rx_sync_r <= '0;
			txw_sync_r <= '0;
			cs_sync_r <= 2'b11;
		end else begin
			cmd_sync_r <= {cmd_sync_r[1:0], cmd_tgl_r};
			rx_sync_r <= {rx_sync_r[1:0], rx_tgl_r};
			txw_sync_r <= {txw_sync_r[1:0], txw_tgl_r};
			cs_sync_r <= {cs_sync_r[0], spi_cs_n};
		end
	end

	wire cmd_ev = cmd_sync_r[2] ^ cmd_sync_r[1];
	wire rx_ev = rx_sync_r[2] ^ rx_sync_r[1];
	wire txw_ev = txw_sync_r[2] ^ txw_sync_r[1];

	logic cmd_ev_q;
	logic [7:0] cmd_q;
	logic [2:0] wcnt_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			cmd_ev_q <= 1'b0;
			cmd_q <= '0;
			wcnt_r <= '0;
		end else begin
			cmd_ev_q <= cmd_ev;
			if (cs_sync_r[1]) begin
				wcnt_r <= '0;
			end else if (cmd_ev) begin
				cmd_q <= cmd_r;
				wcnt_r <= '0;
			end else if (rx_ev && (wcnt_r != 3'd7)) begin
				wcnt_r <= wcnt_r + 1'b1;
			end
		end
	end

	wire is_csr_wr = (cmd_q[7:4] == 4'h8);
	wire is_csr_rd = (cmd_q[7:4] == 4'h0);
	wire is_a_wr = (cmd_q == 8'hA0);
	wire is_b_wr = (cmd_q == 8'hB0);
	wire is_c_rd = (cmd_q == 8'h40);

	// stage rdata
	logic pop_q;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			tx_word_r <= '0;
			pop_q <= 1'b0;
		end else begin
			pop_q <= o_c_pop;
			if (i_csr_rvalid && is_csr_rd) begin
				tx_word_r <= i_csr_rdata;
			end else if ((cmd_ev_q && is_c_rd) || pop_q) begin
				tx_word_r <= i_c_valid ? i_c_data : '0;
			end
		end
	end

	assign o_csr_wr = rx_ev && is_csr_wr && (wcnt_r == 3'd0);
	assign o_csr_rd = cmd_ev_q && is_csr_rd;
	assign o_csr_sel = cmd_q[1:0];
	assign o_csr_wdata = rx_word_r;

	assign o_a_valid = rx_ev && is_a_wr;
	assign o_a_data = rx_word_r;

	assign o_b_valid = rx_ev && is_b_wr && (wcnt_r < 3'd4);
	assign o_b_lane = wcnt_r[1:0];
	assign o_b_data = rx_word_r;

	assign o_c_pop = txw_ev && is_c_rd;

	/* verilator lint_off UNUSEDSIGNAL */
	wire _unused = &{1'b0, cmd_q[3:2]};
	/* verilator lint_on UNUSEDSIGNAL */

endmodule
`default_nettype none
