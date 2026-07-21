`timescale 1ns/1ps

// tb_matmul_accel: end to end over the stream channels (a/b/c) plus the
//   csr control channel, the same interfaces spi_if drives.
//   phase 1: single job, irq at results-ready, status bits, pop drain
//   phase 2: three matrices queued back to back, 48 in-order results and
//            exactly 3 stream entries (the old ctrl dropped queued jobs)
//   phase 3: fill all 11 in_fifo slots with en off, overflow flag on the
//            45th word, w1c, then drain every queued job
//   make xrun TOP=tb_matmul_accel
module tb_matmul_accel;
	localparam integer DW = 32;
	localparam integer N = 4;
	localparam integer EW = 8;
	localparam integer NUM_SLOTS = 11; // in_fifo capacity in matrices
	localparam integer RES_DEPTH = 4;  // out_fifo depth
	localparam integer BATCH = 3;
	localparam int SGN_MIN = -(1 << (EW-1));

	localparam logic [1:0] SEL_CTRL = 2'd0;
	localparam logic [1:0] SEL_STATUS = 2'd1;
	localparam logic [1:0] SEL_IRQ = 2'd2;

	localparam int ST_BUSY = 0, ST_AEMPTY = 1, ST_AFULL = 2, ST_DONE = 3, ST_RESV = 4;

	logic clk = 1'b0;
	always #5 clk = ~clk;

	logic rstn;
	logic csr_wr, csr_rd;
	logic [1:0] csr_sel;
	logic [DW-1:0] csr_wdata, csr_rdata;
	logic csr_rvalid;
	logic a_valid;
	logic [DW-1:0] a_data;
	logic b_valid;
	logic [1:0] b_lane;
	logic [DW-1:0] b_data;
	logic c_pop, c_valid;
	logic [DW-1:0] c_data;
	logic o_irq;

`ifdef GLS
	matmul_accel dut (
`else
	matmul_accel #(
		.CSR_DATA_W(DW)
	) dut (
`endif
		.clk         (clk),
		.rstn        (rstn),
		.i_csr_wr    (csr_wr),
		.i_csr_rd    (csr_rd),
		.i_csr_sel   (csr_sel),
		.i_csr_wdata (csr_wdata),
		.o_csr_rdata (csr_rdata),
		.o_csr_rvalid(csr_rvalid),
		.i_a_valid   (a_valid),
		.i_a_data    (a_data),
		.i_b_valid   (b_valid),
		.i_b_lane    (b_lane),
		.i_b_data    (b_data),
		.i_c_pop     (c_pop),
		.o_c_data    (c_data),
		.o_c_valid   (c_valid),
		.o_irq       (o_irq)
	);

	int B [N][N];
	int A [NUM_SLOTS][N][N], C [NUM_SLOTS][N][N];
	int pass, fail;
	int jobs_done;

	// one result-stream entry per computed matrix
	logic stream_spy_q;
	always @(posedge clk) begin
		if (rstn) begin
			stream_spy_q <= dut.u_array.o_result_valid;
			if (dut.u_array.o_result_valid && !stream_spy_q) begin
				jobs_done++;
			end
		end
	end

	task automatic check(input string name, input int got, input int exp);
		if (got === exp) begin
			pass++;
		end else begin
			fail++;
			$display("FAIL %s got %0d (0x%h) expected %0d (0x%h)", name, got, got, exp, exp);
		end
	endtask

	// channel drivers, single cycle pulses like spi_if emits
	task automatic reg_write(input logic [1:0] sel, input logic [DW-1:0] data);
		@(negedge clk);
		csr_wr <= 1'b1;
		csr_sel <= sel;
		csr_wdata <= data;
		@(negedge clk);
		csr_wr <= 1'b0;
	endtask

	task automatic reg_read(input logic [1:0] sel, output logic [DW-1:0] data);
		@(negedge clk);
		csr_rd <= 1'b1;
		csr_sel <= sel;
		@(negedge clk);
		csr_rd <= 1'b0;
		if (csr_rvalid !== 1'b1) begin
			fail++;
			$display("FAIL rvalid not asserted one cycle after rd");
		end
		data = csr_rdata;
	endtask

	task automatic a_word(input logic [DW-1:0] w);
		@(negedge clk);
		a_valid <= 1'b1;
		a_data <= w;
		@(negedge clk);
		a_valid <= 1'b0;
	endtask

	task automatic b_word(input logic [1:0] lane, input logic [DW-1:0] w);
		@(negedge clk);
		b_valid <= 1'b1;
		b_lane <= lane;
		b_data <= w;
		@(negedge clk);
		b_valid <= 1'b0;
	endtask

	// fwft head + pop, waits for the next element across job boundaries
	task automatic c_read(output logic [DW-1:0] w);
		@(negedge clk);
		while (!c_valid) @(negedge clk);
		w = c_data;
		c_pop <= 1'b1;
		@(negedge clk);
		c_pop <= 1'b0;
	endtask

	function automatic [DW-1:0] status_exp(input bit busy_, input bit aempty,
	                                       input bit afull, input bit done_, input bit resv,
	                                       input int alev, input int rlev);
		return {8'h0, rlev[7:0], alev[7:0], 3'h0, resv, done_, afull, aempty, busy_};
	endfunction

	task automatic load_b;
		logic [DW-1:0] word;
		for (int i = 0; i < N; i++) begin
			word = '0;
			for (int j = 0; j < N; j++) begin
				word[EW*j +: EW] = B[i][j][EW-1:0];
			end
			b_word(i[1:0], word);
		end
	endtask

	task automatic push_a(input int m);
		logic [DW-1:0] word;
		for (int i = 0; i < N; i++) begin
			word = '0;
			for (int j = 0; j < N; j++) begin
				word[EW*j +: EW] = A[m][i][j][EW-1:0];
			end
			a_word(word);
		end
	endtask

	task automatic gen_matrix(input int m);
		for (int i = 0; i < N; i++)
			for (int j = 0; j < N; j++)
				A[m][i][j] = $urandom_range(0, 255) + SGN_MIN;
		for (int i = 0; i < N; i++)
			for (int j = 0; j < N; j++) begin
				C[m][i][j] = 0;
				for (int k = 0; k < N; k++)
					C[m][i][j] += A[m][i][k] * B[k][j];
			end
	endtask

	// results stream row major, one element per pop, in matrix order
	task automatic read_results(input int m);
		logic [DW-1:0] rd;
		for (int idx = 0; idx < N*N; idx++) begin
			c_read(rd);
			check($sformatf("m%0d C[%0d][%0d]", m, idx/N, idx%N), int'(rd), C[m][idx/N][idx%N]);
		end
	endtask

	logic [DW-1:0] rd_val;

	initial begin
`ifdef DUMP
		$dumpfile("dump.vcd");
		$dumpvars(0, tb_matmul_accel);
`endif
		$display("MATMUL ACCEL TB: N=%0d EW=%0d slots=%0d res_depth=%0d", N, EW, NUM_SLOTS, RES_DEPTH);

		rstn = 1'b0;
		csr_wr = 0; csr_rd = 0; csr_sel = '0; csr_wdata = '0;
		a_valid = 0; a_data = '0;
		b_valid = 0; b_lane = '0; b_data = '0;
		c_pop = 0;
		stream_spy_q = 0;
		repeat (5) @(posedge clk);
		@(negedge clk);
		rstn = 1'b1;
		repeat (2) @(posedge clk);

		reg_read(SEL_STATUS, rd_val);
		check("status after reset", int'(rd_val), int'(status_exp(0, 1, 0, 0, 0, 0, 0)));
		check("irq low after reset", int'({31'h0, o_irq}), 0);

		// stationary weights, signed random, loaded once while idle
		for (int i = 0; i < N; i++)
			for (int j = 0; j < N; j++)
				B[i][j] = $urandom_range(0, 255) + SGN_MIN;
		load_b();

		// phase 1: one job, irq fires at results-ready, drain by pops
		reg_write(SEL_CTRL, 32'h3); // en + irq en
		gen_matrix(0);
		push_a(0);
		wait (o_irq);
		repeat (6) @(negedge clk); // let the small fifo fill to its cap
		reg_read(SEL_STATUS, rd_val);
		check("status at irq", int'(rd_val), int'(status_exp(1, 1, 0, 0, 1, 0, RES_DEPTH)));
		read_results(0);
		repeat (6) @(negedge clk); // drain-done settles busy/done
		reg_read(SEL_STATUS, rd_val);
		check("status results drained", int'(rd_val), int'(status_exp(0, 1, 0, 1, 0, 0, 0)));
		reg_read(SEL_IRQ, rd_val);
		check("irq pending", int'(rd_val), 1);
		reg_write(SEL_IRQ, 32'h1);
		reg_read(SEL_IRQ, rd_val);
		check("irq w1c", int'(rd_val), 0);
		check("irq line released", int'({31'h0, o_irq}), 0);
		check("jobs after phase1", jobs_done, 1);

		// phase 2: queue three matrices back to back, every one must be
		// computed, in order (the old ctrl popped queued jobs uncomputed)
		for (int m = 0; m < BATCH; m++) begin
			gen_matrix(m);
		end
		for (int m = 0; m < BATCH; m++) begin
			push_a(m);
		end
		for (int m = 0; m < BATCH; m++) begin
			read_results(m);
		end
		repeat (6) @(negedge clk);
		reg_read(SEL_STATUS, rd_val);
		check("status after batch", int'(rd_val), int'(status_exp(0, 1, 0, 1, 0, 0, 0)));
		check("jobs after batch", jobs_done, 1 + BATCH);
		reg_write(SEL_IRQ, 32'h1);

		// phase 3: en off, fill every fifo slot, overflow on one more word
		reg_write(SEL_CTRL, 32'h2); // irq en only
		for (int m = 0; m < NUM_SLOTS; m++) begin
			gen_matrix(m);
			push_a(m);
		end
		reg_read(SEL_STATUS, rd_val);
		check("fifo full", int'(rd_val[ST_AFULL]), 1);
		check("fifo level", int'(rd_val[15:8]), NUM_SLOTS);
		a_word(32'hBAD0_BAD0); // dropped, must flag
		reg_read(SEL_IRQ, rd_val);
		check("ovfl flagged", int'(rd_val), 2);
		reg_write(SEL_IRQ, 32'h2);
		reg_read(SEL_IRQ, rd_val);
		check("ovfl w1c", int'(rd_val), 0);

		// re-enable and drain all queued jobs
		reg_write(SEL_CTRL, 32'h3);
		for (int m = 0; m < NUM_SLOTS; m++) begin
			read_results(m);
		end
		repeat (6) @(negedge clk);
		reg_read(SEL_STATUS, rd_val);
		check("status after drain", int'(rd_val), int'(status_exp(0, 1, 0, 1, 0, 0, 0)));
		check("jobs after drain", jobs_done, 1 + BATCH + NUM_SLOTS);
		reg_write(SEL_IRQ, 32'h1);

		$display("RESULT: %0d passed, %0d failed", pass, fail);
		if (fail != 0) begin
			$fatal(1, "tb_matmul_accel FAILED (%0d checks)", fail);
		end
		$display("TEST PASSED");
		$finish;
	end

	// timeout
	initial begin
		#2000000;
		$fatal(1, "tb_matmul_accel TIMEOUT");
	end
endmodule
