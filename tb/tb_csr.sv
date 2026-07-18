`timescale 1ps/1ps

module tb_csr;
	localparam integer DW = 32;
	localparam integer AW = 8;
	localparam integer N = 4;
	localparam integer WE_W =8;
	localparam integer LANE_W = $clog2(N);
	localparam integer ROW_W = N*WE_W;

	logic clk, rstn;
	logic en_in, wr_en;
	logic [AW-1:0] addr;
	logic [DW-1:0] wdata, rdata;
	logic b_en;
	logic [LANE_W-1:0] b_lane;
	logic [ROW_W-1:0] b_wdata;
	logic enable_out;
	logic sign_enable;
	logic busy, empty, full, done;
	logic [7:0] level;
	logic jobdone, irq;

	initial clk = 0;
	always #5 clk = ~clk;

	csr #(DW, AW, N, WE_W) dut (
		.clk         (clk),
		.rstn        (rstn),
		.i_en        (en_in),
		.i_wr_en     (wr_en),
		.i_addr      (addr),
		.i_wdata     (wdata),
		
		.o_rdata     (rdata),
		.o_b_en      (b_en),
		.o_b_lane    (b_lane),
		.o_b_wdata   (b_wdata),
		.o_enable    (enable_out),
		.o_sign_en   (sign_enable),
		
		.i_busy      (busy),
		.i_empty     (empty),
		.i_full      (full),
		.i_done      (done),
		.i_level     (level),
		.i_jobdone   (jobdone),
		.o_irq       (irq)
	);

	property outputs_low_during_reset;
		@(posedge dut.clk) (!dut.rstn)
		|-> (dut.o_sign_en == 0 && dut.o_enable == 0);
	endproperty
	assert_outputs_low_during_reset : assert property (outputs_low_during_reset);

	task automatic reset_dut;
		rstn <= 1'b1;
		repeat (2) @(posedge clk);
		rstn <= 1'b0;
		repeat (5) @(posedge clk);
		rstn <= 1'b1;
		@(posedge clk);
		$display("Reset complete");
	endtask

	task automatic csr_wr(input logic [AW-1:0] addr, [DW-1:0] wdata, output logic [DW-1:0] rdata);
		dut.i_addr = addr;
		dut.i_wdata = wdata;
		@(posedge clk);
		rdata = dut.o_rdata;
	endtask

	task automatic csr_rd(input logic [AW-1:0] read_addr, output logic [DW-1:0] read_data);
		en_in = 1'b1;
		wr_en = 1'b0;
		addr  = read_addr;
		@(posedge clk);
		en_in = 1'b0;
		@(posedge clk);
		read_data = rdata;
	endtask

	task automatic status_adressing();
		logic [DW-1:0] read_val;
		logic [DW-1:0] expected_val = 32'h0000FF0F; 
		level = 8'hFF;
		done  = 1'b1;
		full  = 1'b1;
		empty = 1'b1;
		busy  = 1'b1;
		@(posedge clk);
		csr_rd(8'h04, read_val);

		if (read_val === expected_val) begin
			$display("PASS: ADDR_STATUS (0x04) Correct max data %h", read_val);
		end else begin
			$error("FAIL: ADDR_STATUS (0x04) Mismatch |  Expected: %h, Got: %h", expected_val, read_val);
		end

		csr_rd(8'h00, read_val);
		
		if (read_val !== expected_val) begin
			$display("PASS Addressing works! ADDR_CTRL (0x00) holds separate data: %h", read_val);
		end else begin
			$error("FAIL Addressing broken! ADDR_CTRL (0x00) leaked status data!");
		end
	endtask

	task automatic monitor_out;
		$monitor("To Array: b_en:%0d  | o_blane=%0d | o_b_data=%0d", dut.o_b_en, dut.o_b_lane, dut.o_b_wdata);
		$monitor("o_enable=%0d | o_sign_en=%0d | o_irq=%0d", dut.o_enable, dut.o_sign_en, dut.o_irq);
	endtask

	initial begin
		rstn = 1'b1;
		en_in = 0;
		wr_en = 0;
		addr = '0;
		wdata = '0;
		busy = 0;
		empty = 0;
		full = 0;
		done = 0;
		level = '0;
		jobdone = 0;
		reset_dut();
		status_adressing();
		
		$finish;
	end

endmodule
