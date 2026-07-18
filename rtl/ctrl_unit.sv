`default_nettype none
`timescale 1ps/1ps

module ctrl_unit (
	input wire clk,
	input wire rstn,
	input wire i_en,
	input wire i_valid_matrix,
	input wire i_result_valid,
	output logic o_start,
	output logic o_matrix_ready,
	output logic o_job_done,
	output logic o_busy
);
	logic run_r, next_run;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			run_r <= 1'b0;
		end else begin
			run_r <= next_run;
		end
	end

	wire matrix_ready = run_r && i_result_valid;
	wire start = !run_r && i_en && i_valid_matrix;

	always_comb begin
		next_run = run_r;
		if (start) begin
			next_run = 1'b1;
		end else if (matrix_ready) begin
			next_run = 1'b0;
		end
	end

	assign o_start = start;
	assign o_matrix_ready = matrix_ready;
	assign o_job_done = matrix_ready;
	assign o_busy = run_r;

endmodule
`default_nettype wire
