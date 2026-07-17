`timescale 1ps/1ps

module tb_sram;
    localparam integer DATA_WIDTH = 32;
	localparam integer ADDR_WIDTH = 9;
	localparam integer DEPTH = 1 << ADDR_WIDTH;

	logic clk, rstn;
    logic p0_en, p0_we, p1_en;
    logic [3:0] p0_wrmask;
    logic [ADDR_WIDTH-1:0] p0_addr, p1_addr;
    logic [DATA_WIDTH-1:0] p0_wdata, p0_rdata, p1_rdata;

    integer errors = 0;

    sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
     ) dut (
        .clk        (clk),
        .rstn       (rstn),
        .i_p0_en    (p0_en),
        .i_p0_we    (p0_we),
        .i_p0_wrmask(p0_wrmask),
        .i_p0_addr  (p0_addr),
        .i_p0_wdata (p0_wdata),
        .o_p0_rdata (p0_rdata),
        .i_p1_en    (p1_en),
        .i_p1_addr  (p1_addr),
        .o_p1_rdata (p1_rdata)
    );

	initial clk = 1'b0;
	always #5 clk = ~clk;

	function automatic [DATA_WIDTH-1:0] pattern(input [ADDR_WIDTH-1:0] a);
		pattern = {7'h5A, a, 7'h25, a};
	endfunction

	task automatic idle;
		p0_en = 1'b0;
		p0_we= 1'b0;
		p0_wrmask = 4'h0;
		p0_addr = '0;
		p0_wdata = '0;
		p1_en = 1'b0;
		p1_addr= '0;
	endtask

	task automatic write(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d);
		@(posedge clk);
		p0_en <= 1'b1;
		p0_we <= 1'b1;
		p0_wrmask <= 4'hF;
		p0_addr <= a;
		p0_wdata  <= d;
		@(posedge clk);
		p0_en <= 1'b0;
		p0_we <= 1'b0;
		p0_wrmask <= 4'h0;
	endtask

	task automatic read_p0(input [ADDR_WIDTH-1:0] a, output [DATA_WIDTH-1:0] d);
		@(posedge clk);
		p0_en <= 1'b1;
		p0_we <= 1'b0;
		p0_addr <= a;
		@(posedge clk);
		p0_en   <= 1'b0;
		@(posedge clk);
		d = p0_rdata;
	endtask

	task automatic read_p1(input [ADDR_WIDTH-1:0] a, output [DATA_WIDTH-1:0] d);
		@(posedge clk);
		p1_en <= 1'b1;
		p1_addr <= a;
		@(posedge clk);
		p1_en <= 1'b0;
		@(posedge clk);
		d = p1_rdata;
	endtask

	task automatic check(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] got, input [DATA_WIDTH-1:0] exp, input string port);
		if (got !== exp) begin
			errors = errors + 1;
			$error("%s addr=%0d: got %h, expected %h", port, a, got, exp);
		end
	endtask

	// write every word in the array
	task automatic fill;
		for (int a = 0; a < DEPTH; a++)
			write(a[ADDR_WIDTH-1:0], pattern(a[ADDR_WIDTH-1:0]));
		$display("fill: wrote %0d words", DEPTH);
	endtask

	// read every word back and compare
	task automatic drain_p1;
		logic [DATA_WIDTH-1:0] d;
		for (int a = 0; a < DEPTH; a++) begin
			read_p1(a[ADDR_WIDTH-1:0], d);
			check(a[ADDR_WIDTH-1:0], d, pattern(a[ADDR_WIDTH-1:0]), "p1");
		end
		$display("drain_p1: read %0d words", DEPTH);
	endtask

	task automatic drain_p0;
		logic [DATA_WIDTH-1:0] d;
		for (int a = 0; a < DEPTH; a++) begin
			read_p0(a[ADDR_WIDTH-1:0], d);
			check(a[ADDR_WIDTH-1:0], d, pattern(a[ADDR_WIDTH-1:0]), "p0");
		end
		$display("drain_p0: read %0d words", DEPTH);
	endtask

	initial begin
		rstn = 1'b1;
		idle();
		fill();
		drain_p1();
		drain_p0();

		if (errors == 0) begin
			$display("TEST PASSED");
		end else begin
			$display("TEST FAILED: %0d errors", errors);
		end
		$finish;
	end

endmodule
