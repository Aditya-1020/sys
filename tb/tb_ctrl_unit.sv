`timescale 1ps/1ps

module tb_ctrl_unit;

	logic clk, rstn;
	logic en, valid_matrix;
	logic result_valid;
	logic start, matrix_ready;
	logic job_done, busy;

	initial clk = 0;
	always #5 clk = ~clk;

	ctrl_unit dut (
		.clk           (clk),
		.rstn          (rstn),
		.i_en          (en),
		.i_valid_matrix(valid_matrix),
		.i_result_valid(result_valid),
		.o_start       (start),
		.o_matrix_ready(matrix_ready),
		.o_job_done    (job_done),
		.o_busy        (busy)
	);

	task automatic check_output;
		assert (dut.o_busy == 0)
			else $error("busy still high during reset at time %0t", $time);
		assert (dut.o_job_done == 0)
			else $error("job_done still high during reset at time %0t", $time);
		assert (dut.o_matrix_ready == 0)
			else $error("matrix_ready still high during reset at time %0t", $time);
		assert (dut.o_start == 0)
			else $error("start still high during reset at time %0t", $time);
	endtask

	task automatic reset_dut;
		rstn <= 1'b1;
		repeat (2) @(posedge clk);
		rstn <= 1'b0;
		repeat (5) @(posedge clk) begin
			check_output();
		end
		rstn <= 1'b1;
		@(posedge clk);
	endtask

	initial begin
		rstn = 1'b0;
		en = 1'b0;
		valid_matrix = 1'b0;
		result_valid = 1'b0;
		reset_dut();

		$finish;
	end

endmodule
