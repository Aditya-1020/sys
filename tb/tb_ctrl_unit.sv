`timescale 1ns/1ps

// tb_ctrl_unit: merged control block. register map (ctrl/status/irq via
//   the csr channel, w1c, overflow flag, b gate) plus the job sequencer
//   against a modeled array: 4 a-row beats in fifo word order, one
//   start + one pop per matrix, irq at results-ready (before drain
//   done), no launch while the array is busy or i_en low. the second
//   matrix is queued mid-job, the case the old ctrl popped uncomputed.
//   make xrun TOP=tb_ctrl_unit
module tb_ctrl_unit;
	localparam integer N = 4;
	localparam integer DW = 8;
	localparam integer ROW_W = N*DW;
	localparam integer MAT_W = N*ROW_W;
	localparam integer COMPUTE_CYCLES = 8; // model: start -> stream entry
	localparam integer DRAIN_CYCLES = 6;   // model: stream entry -> done

	localparam logic [MAT_W-1:0] MAT1 = {32'h100F_0E0D, 32'h0C0B_0A09, 32'h0807_0605, 32'h0403_0201};
	localparam logic [MAT_W-1:0] MAT2 = {32'hD0D1_D2D3, 32'hC0C1_C2C3, 32'hB0B1_B2B3, 32'hA0A1_A2A3};

	logic clk = 1'b0;
	always #5 clk = ~clk;

	logic rstn;
	logic csr_wr, csr_rd;
	logic [1:0] csr_sel;
	logic [31:0] csr_wdata, csr_rdata;
	logic csr_rvalid;
	logic b_valid, b_en;
	logic a_valid, a_ready;
	logic matrix_valid;
	logic [MAT_W-1:0] matrix_data;
	logic matrix_ready;
	logic ld_a_valid;
	logic [ROW_W-1:0] a_row;
	logic start;
	logic array_busy, array_done, array_res_valid;
	logic in_empty, in_full;
	logic [7:0] in_level;
	logic res_valid;
	logic [7:0] res_level;
	logic irq;

	int pass, fail;
	int start_seen, pop_seen, irq_rises;
	int row_beats;

	ctrl_unit #(
		.MATRIX_SIZE(N),
		.DATA_WIDTH (DW)
	) dut (
		.clk              (clk),
		.rstn             (rstn),
		.i_csr_wr         (csr_wr),
		.i_csr_rd         (csr_rd),
		.i_csr_sel        (csr_sel),
		.i_csr_wdata      (csr_wdata),
		.o_csr_rdata      (csr_rdata),
		.o_csr_rvalid     (csr_rvalid),
		.i_b_valid        (b_valid),
		.o_b_en           (b_en),
		.i_a_valid        (a_valid),
		.i_a_ready        (a_ready),
		.i_matrix_valid   (matrix_valid),
		.i_matrix_data    (matrix_data),
		.o_matrix_ready   (matrix_ready),
		.o_a_valid        (ld_a_valid),
		.o_a_row          (a_row),
		.o_start          (start),
		.i_array_busy     (array_busy),
		.i_array_done     (array_done),
		.i_array_res_valid(array_res_valid),
		.i_in_empty       (in_empty),
		.i_in_full        (in_full),
		.i_in_level       (in_level),
		.i_res_valid      (res_valid),
		.i_res_level      (res_level),
		.o_irq            (irq)
	);

	task automatic check(input string name, input int got, input int exp);
		if (got === exp) begin
			pass++;
		end else begin
			fail++;
			$display("FAIL %s got %0d (0x%h) expected %0d (0x%h)", name, got, got, exp, exp);
		end
	endtask

	// array model: busy from start, res_valid through the stream window,
	// sticky done once drained, done cleared again by the next start.
	// plain always: the register tests also poke these signals directly
	int job_timer;
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			array_busy <= 1'b0;
			array_done <= 1'b0;
			array_res_valid <= 1'b0;
			job_timer <= 0;
		end else if (start) begin
			array_busy <= 1'b1;
			array_done <= 1'b0;
			array_res_valid <= 1'b0;
			job_timer <= COMPUTE_CYCLES + DRAIN_CYCLES;
		end else if (array_busy) begin
			job_timer <= job_timer - 1;
			if (job_timer == DRAIN_CYCLES + 1) begin
				array_res_valid <= 1'b1; // stream entry: results ready
			end
			if (job_timer == 1) begin
				array_busy <= 1'b0;
				array_done <= 1'b1;
				array_res_valid <= 1'b0;
			end
		end
	end

	// protocol monitors
	logic irq_q;
	always @(posedge clk) begin
		if (rstn) begin
			if (ld_a_valid) begin
				check($sformatf("row beat %0d data", row_beats),
				      int'(a_row), int'(matrix_data[ROW_W*row_beats +: ROW_W]));
				row_beats++;
			end
			if (start) begin
				start_seen++;
				check("start only while array idle", int'(array_busy), 0);
				check("all rows loaded before start", row_beats, N);
				row_beats = 0;
			end
			if (matrix_ready) begin
				pop_seen++;
				check("pop only while matrix valid", int'(matrix_valid), 1);
			end
			irq_q <= irq;
			if (irq && !irq_q) begin
				irq_rises++;
				check("irq before drain done", int'(array_done), 0);
			end
		end
	end

	// csr channel, single cycle strobes
	task automatic reg_write(input logic [1:0] sel, input logic [31:0] data);
		@(negedge clk);
		csr_wr <= 1'b1;
		csr_sel <= sel;
		csr_wdata <= data;
		@(negedge clk);
		csr_wr <= 1'b0;
	endtask

	task automatic reg_read(input logic [1:0] sel, output logic [31:0] data);
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

	logic [31:0] rd_val;

	initial begin
`ifdef DUMP
		$dumpfile("dump.vcd");
		$dumpvars(0, tb_ctrl_unit);
`endif
		$display("CTRL UNIT TB: N=%0d DW=%0d", N, DW);
		rstn = 1'b0;
		csr_wr = 0; csr_rd = 0; csr_sel = '0; csr_wdata = '0;
		b_valid = 0; a_valid = 0; a_ready = 1;
		matrix_valid = 0; matrix_data = '0;
		in_empty = 1; in_full = 0; in_level = '0;
		res_valid = 0; res_level = '0;
		irq_q = 0;
		repeat (2) @(posedge clk);
		repeat (3) @(negedge clk) begin
			check("start low in reset", int'(start), 0);
			check("matrix_ready low in reset", int'(matrix_ready), 0);
			check("a_valid low in reset", int'(ld_a_valid), 0);
			check("irq low in reset", int'(irq), 0);
		end
		@(negedge clk);
		rstn = 1'b1;
		repeat (2) @(posedge clk);

		// register map: status field placement, ctrl readback
		in_level = 8'hFF; res_level = 8'h10;
		in_empty = 1; in_full = 1; array_done = 1; res_valid = 1;
		@(posedge clk);
		reg_read(2'd1, rd_val);
		check("status field placement", int'(rd_val), 32'h0010FF1E);
		reg_read(2'd0, rd_val);
		check("ctrl resets to 0", int'(rd_val), 0);
		in_level = '0; res_level = '0;
		in_full = 0; array_done = 0; res_valid = 0;

		reg_write(2'd0, 32'h3); // en + irq en
		reg_read(2'd0, rd_val);
		check("ctrl readback", int'(rd_val), 3);

		// b gate: open while idle, closed while the array is busy
		@(negedge clk);
		b_valid <= 1'b1;
		@(negedge clk);
		check("b passes while idle", int'(b_en), 1);
		array_busy = 1'b1;
		@(negedge clk);
		check("b gated while busy", int'(b_en), 0);
		array_busy = 1'b0;
		b_valid <= 1'b0;

		// a overflow: sticky, w1c on irq bit 1
		@(negedge clk);
		a_ready <= 1'b0;
		a_valid <= 1'b1;
		@(negedge clk);
		a_valid <= 1'b0;
		a_ready <= 1'b1;
		reg_read(2'd2, rd_val);
		check("ovfl sticky", int'(rd_val), 2);
		reg_write(2'd2, 32'h2);
		reg_read(2'd2, rd_val);
		check("ovfl w1c", int'(rd_val), 0);

		// job 1, and queue the second matrix the moment the first is popped
		@(negedge clk);
		matrix_data <= MAT1;
		matrix_valid <= 1'b1;
		while (!matrix_ready) @(negedge clk);
		matrix_data <= MAT2;
		while (!irq) @(negedge clk); // results ready fires the irq
		while (!array_done) @(negedge clk);
		@(negedge clk);
		check("job1 one start", start_seen, 1);
		check("job1 one pop", pop_seen, 1);
		check("job1 one irq", irq_rises, 1);
		reg_write(2'd2, 32'h1); // w1c

		// job 2 launches on its own once the array is idle
		while (!matrix_ready) @(negedge clk);
		@(negedge clk); // hold valid through the pop edge, like in_fifo does
		matrix_valid <= 1'b0;
		while (!array_done) @(negedge clk);
		@(negedge clk);
		check("job2 one start", start_seen, 2);
		check("job2 one pop", pop_seen, 2);
		check("job2 one irq", irq_rises, 2);
		reg_write(2'd2, 32'h1);
		reg_read(2'd2, rd_val);
		check("irq w1c", int'(rd_val), 0);
		check("irq line low", int'(irq), 0);

		repeat (4) @(negedge clk);
		check("no spurious start", start_seen, 2);
		check("no spurious pop", pop_seen, 2);
		check("no spurious irq", irq_rises, 2);

		$display("RESULT: %0d passed, %0d failed", pass, fail);
		if (fail != 0) begin
			$fatal(1, "tb_ctrl_unit FAILED (%0d checks)", fail);
		end
		$display("TEST PASSED");
		$finish;
	end

	// timeout
	initial begin
		#100000;
		$fatal(1, "tb_ctrl_unit TIMEOUT");
	end
endmodule
