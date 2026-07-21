`timescale 1ps/1ps

module tb_in_fifo;
	localparam integer NUM_SLOTS = 11;
	localparam integer MAT_W = 128;
	localparam integer DATA_W = 32;
	localparam integer WORDS = MAT_W / DATA_W; // 4

	logic clk, rstn;
	logic i_wr_valid;
	logic [DATA_W-1:0] i_wr_data;
	logic o_wr_ready;
	logic i_matrix_ready;
	logic o_matrix_valid;
	logic [MAT_W-1:0] o_matrix_data;
	logic [7:0] o_level;
	logic o_empty, o_full;

	integer errors = 0;
	logic [MAT_W-1:0] exp_q [$];

	in_fifo #(
		.NUM_SLOTS(NUM_SLOTS),
		.MAT_W    (MAT_W),
		.DATA_W   (DATA_W)
	 ) dut (
		.clk           (clk),
		.rstn          (rstn),
		.i_wr_valid    (i_wr_valid),
		.i_wr_data     (i_wr_data),
		.o_wr_ready    (o_wr_ready),
		.i_matrix_ready(i_matrix_ready),
		.o_matrix_valid(o_matrix_valid),
		.o_matrix_data (o_matrix_data),
		.o_level       (o_level),
		.o_empty       (o_empty),
		.o_full        (o_full)
	);

	initial clk = 1'b0;
	always #5 clk = ~clk;

	function automatic [DATA_W-1:0] word_data(input int mat, input int w);
		word_data = {16'(mat), 8'(w), 8'hA5};
	endfunction

	function automatic [MAT_W-1:0] exp_matrix(input int mat);
		exp_matrix = {word_data(mat,3), word_data(mat,2), word_data(mat,1), word_data(mat,0)};
	endfunction

	task automatic check_eq(input [63:0] got, input [63:0] exp, input string what);
		if (got !== exp) begin
			errors = errors + 1;
			$error("%s: got %0d, expected %0d @%0t", what, got, exp, $time);
		end
	endtask

	task automatic put_word(input [DATA_W-1:0] d);
		i_wr_data  <= d;
		i_wr_valid <= 1'b1;
		do @(posedge clk); while (!o_wr_ready);
	endtask

	task automatic stream_n(input int start_mat, input int count);
		for (int m = 0; m < count; m++) begin
			for (int w = 0; w < WORDS; w++) put_word(word_data(start_mat + m, w));
			exp_q.push_back(exp_matrix(start_mat + m));
		end
		i_wr_valid <= 1'b0;
	endtask

	task automatic consume_matrix(input int job_cycles);
		logic [MAT_W-1:0] expv;
		@(negedge clk);
		while (!o_matrix_valid) @(negedge clk);
		if (exp_q.size() == 0) begin
			errors = errors + 1;
			$error("matrix_valid but scoreboard empty @%0t", $time);
			expv = o_matrix_data;
		end else begin
			expv = exp_q.pop_front();
		end
		if (o_matrix_data !== expv) begin
			errors = errors + 1;
			$error("matrix data: got %h, expected %h @%0t", o_matrix_data, expv, $time);
		end
		// held matrix must stay stable for the whole job
		repeat (job_cycles) begin
			@(negedge clk);
			if (!o_matrix_valid) begin
				errors = errors + 1;
				$error("valid dropped mid-job @%0t", $time);
			end
			if (o_matrix_data !== expv) begin
				errors = errors + 1;
				$error("held matrix changed mid-job @%0t", $time);
			end
		end
		i_matrix_ready <= 1'b1;
		@(posedge clk);
		i_matrix_ready <= 1'b0;
	endtask

	task automatic do_reset;
		rstn = 1'b0;
		i_wr_valid = 1'b0;
		i_wr_data = '0;
		i_matrix_ready = 1'b0;
		repeat (4) @(negedge clk);
		rstn = 1'b1;
		@(negedge clk);
	endtask

	task automatic phase_a;
		$display("[A] depth / backpressure");
		i_matrix_ready = 1'b0; // no consumer yet, let the fifo fill
		stream_n(0, 10);
		@(negedge clk);
		check_eq(64'(o_level), 10, "level after 10");
		check_eq(64'(o_full), 0, "full after 10");
		check_eq(64'(o_wr_ready), 1, "wr_ready after 10");

		// write the 11th: while its words stream in, 10 are still in flight
		put_word(word_data(10, 0));
		put_word(word_data(10, 1));
		put_word(word_data(10, 2));
		@(negedge clk);
		check_eq(64'(o_level), 10, "level mid-write 11th (10 in flight)");
		check_eq(64'(o_wr_ready), 1, "wr_ready mid-write 11th");
		check_eq(64'(o_full), 0, "full mid-write 11th");

		put_word(word_data(10, 3)); // 4th word -> push
		i_wr_valid <= 1'b0;
		exp_q.push_back(exp_matrix(10));
		@(negedge clk);
		check_eq(64'(o_level), 11, "level after 11 (full)");
		check_eq(64'(o_full), 1, "full after 11");
		check_eq(64'(o_wr_ready), 0, "wr_ready gated when full");
	endtask

	task automatic phase_b;
		$display("[B] drain 11, check data/order/hold-stability");
		for (int m = 0; m < 11; m++) consume_matrix(5);
		@(negedge clk);
		check_eq(64'(o_empty), 1, "empty after drain");
		check_eq(64'(o_level), 0, "level 0 after drain");
		check_eq(64'(o_matrix_valid), 0, "valid low after drain");
	endtask

	task automatic phase_c;
		localparam int K = 30;
		$display("[C] decoupled streaming, %0d matrices", K);
		fork
			stream_n(100, K);
			begin
				for (int m = 0; m < K; m++) consume_matrix($urandom_range(2, 15));
			end
		join
		@(negedge clk);
		check_eq(64'(exp_q.size()), 0, "scoreboard drained");
		check_eq(64'(o_empty), 1, "empty after phase C");
	endtask

	initial begin
`ifdef DUMP
		$dumpfile("dump.vcd");
		$dumpvars(0, tb_in_fifo);
`endif
		do_reset();
		check_eq(64'(o_empty), 1, "empty at reset");
		check_eq(64'(o_full), 0, "full at reset");
		check_eq(64'(o_level), 0, "level at reset");

		phase_a();
		phase_b();
		phase_c();

		if (errors == 0) begin
			$display("TEST PASSED");
		end else begin
			$display("TEST FAILED: %0d errors", errors);
		end
		$finish;
	end

	initial begin
		#500000;
		$error("TIMEOUT");
		$finish;
	end

endmodule
