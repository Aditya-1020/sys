`default_nettype none
`timescale 1ps/1ps

module matmul_accel #(
	parameter int unsigned CSR_DATA_W = 32
)(
	`ifdef USE_POWER_PINS
	inout VCCD1,
	inout VSSD1,
	`endif
	input wire clk,
	input wire rstn,

	input wire i_csr_wr,
	input wire i_csr_rd,
	input wire [1:0] i_csr_sel,
	input wire [CSR_DATA_W-1:0] i_csr_wdata,
	output wire [CSR_DATA_W-1:0] o_csr_rdata,
	output wire o_csr_rvalid,

	input wire i_a_valid,
	input wire [CSR_DATA_W-1:0] i_a_data,

	input wire i_b_valid,
	input wire [1:0] i_b_lane,
	input wire [CSR_DATA_W-1:0] i_b_data,

	input wire i_c_pop,
	output wire [CSR_DATA_W-1:0] o_c_data,
	output wire o_c_valid,

	output wire o_irq
);
	localparam int unsigned MATRIX_SIZE = 4;
	localparam int unsigned DATA_WIDTH = 8;
	localparam int unsigned RESULT_WIDTH = (2*DATA_WIDTH) + $clog2(MATRIX_SIZE); // 18
	localparam int unsigned ROW_W = MATRIX_SIZE * DATA_WIDTH; // 32
	localparam int unsigned MAT_W = MATRIX_SIZE * ROW_W; // 128
	localparam int unsigned RESULT_DEPTH = 4;

	wire a_ready_w;
	wire matrix_valid_w, matrix_ready_w;
	wire [MAT_W-1:0] matrix_data_w;
	wire in_empty_w, in_full_w;
	wire [7:0] in_level_w;

	wire ctrl_a_valid_w, ctrl_start_w, b_en_w;
	wire [ROW_W-1:0] ctrl_a_row_w;
	wire array_busy_w, array_done_w;

	wire res_wr_valid_w, res_wr_ready_w;
	wire [RESULT_WIDTH-1:0] res_wr_data_w;

	wire res_valid_w;
	wire [RESULT_WIDTH-1:0] res_data_w;
	wire [7:0] res_level_w;
	wire res_empty_w, res_full_w;

	ctrl_unit #(
		.MATRIX_SIZE(MATRIX_SIZE),
		.DATA_WIDTH (DATA_WIDTH),
		.CSR_DATA_W (CSR_DATA_W)
	) u_ctrl (
		.clk              (clk),
		.rstn             (rstn),
		.i_csr_wr         (i_csr_wr),
		.i_csr_rd         (i_csr_rd),
		.i_csr_sel        (i_csr_sel),
		.i_csr_wdata      (i_csr_wdata),
		.o_csr_rdata      (o_csr_rdata),
		.o_csr_rvalid     (o_csr_rvalid),
		.i_b_valid        (i_b_valid),
		.o_b_en           (b_en_w),
		.i_a_valid        (i_a_valid),
		.i_a_ready        (a_ready_w),
		.i_matrix_valid   (matrix_valid_w),
		.i_matrix_data    (matrix_data_w),
		.o_matrix_ready   (matrix_ready_w),
		.o_a_valid        (ctrl_a_valid_w),
		.o_a_row          (ctrl_a_row_w),
		.o_start          (ctrl_start_w),
		.i_array_busy     (array_busy_w),
		.i_array_done     (array_done_w),
		.i_array_res_valid(res_wr_valid_w),
		.i_in_empty       (in_empty_w),
		.i_in_full        (in_full_w),
		.i_in_level       (in_level_w),
		.i_res_valid      (res_valid_w),
		.i_res_level      (res_level_w),
		.o_irq            (o_irq)
	);

	in_fifo #(
		.NUM_SLOTS(11),
		.MAT_W    (MAT_W),
		.DATA_W   (CSR_DATA_W)
	) u_in_fifo (
		`ifdef USE_POWER_PINS
		.VCCD1(VCCD1),
		.VSSD1(VSSD1),
		`endif
		.clk           (clk),
		.rstn          (rstn),
		.i_wr_valid    (i_a_valid),
		.i_wr_data     (i_a_data),
		.o_wr_ready    (a_ready_w),
		.i_matrix_ready(matrix_ready_w),
		.o_matrix_valid(matrix_valid_w),
		.o_matrix_data (matrix_data_w),
		.o_level       (in_level_w),
		.o_empty       (in_empty_w),
		.o_full        (in_full_w)
	);

	systolic_array #(
		.MATRIX_SIZE(MATRIX_SIZE),
		.DATA_WIDTH (DATA_WIDTH)
	) u_array (
		.clk           (clk),
		.rstn          (rstn),
		.i_start       (ctrl_start_w),
		.i_a_valid     (ctrl_a_valid_w),
		.i_ld_a        (ctrl_a_row_w),
		.i_b_en        (b_en_w),
		.i_b_lane      (i_b_lane),
		.i_b_wdata     (i_b_data[ROW_W-1:0]),
		.o_result_data (res_wr_data_w),
		.o_result_valid(res_wr_valid_w),
		.i_result_ready(res_wr_ready_w),
		.o_done        (array_done_w),
		.o_busy        (array_busy_w)
	);

	out_fifo #(
		.DATA_W(RESULT_WIDTH),
		.DEPTH (RESULT_DEPTH)
	) u_out_fifo (
		.clk       (clk),
		.rstn      (rstn),
		.i_wr_valid(res_wr_valid_w),
		.i_wr_data (res_wr_data_w),
		.o_wr_ready(res_wr_ready_w),
		.o_rd_valid(res_valid_w),
		.o_rd_data (res_data_w),
		.i_rd_ready(i_c_pop),
		.o_level   (res_level_w),
		.o_empty   (res_empty_w),
		.o_full    (res_full_w)
	);

	assign o_c_data = {{(CSR_DATA_W-RESULT_WIDTH){res_data_w[RESULT_WIDTH-1]}}, res_data_w};
	assign o_c_valid = res_valid_w;

	/* verilator lint_off UNUSEDSIGNAL */
	wire _unused = &{1'b0, res_empty_w, res_full_w};
	/* verilator lint_on UNUSEDSIGNAL */

endmodule
`default_nettype wire
