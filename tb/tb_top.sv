`timescale 1ps/1ps

module tb_top;

	logic clk;
	logic rstn;

	// AXI-Lite slave
	logic [7:0] i_s_axil_awaddr;
	logic i_s_axil_awvalid;
	wire o_s_axil_awready;

	logic [31:0] i_s_axil_wdata;
	logic [3:0] i_s_axil_wstrb;
	logic i_s_axil_wvalid;
	wire o_s_axil_wready;

	wire [1:0] o_s_axil_bresp;
	wire o_s_axil_bvalid;
	logic i_s_axil_bready;

	logic [7:0] i_s_axil_araddr;
	logic i_s_axil_arvalid;
	wire o_s_axil_arready;

	wire [31:0] o_s_axil_rdata;
	wire [1:0] o_s_axil_rresp;
	wire o_s_axil_rvalid;
	logic i_s_axil_rready;

	// AXI master read
	wire [3:0] o_m_axi_arid;
	wire [31:0] o_m_axi_araddr;
	wire [7:0] o_m_axi_arlen;
	wire [2:0] o_m_axi_arsize;
	wire [1:0] o_m_axi_arburst;
	wire o_m_axi_arlock;
	wire [3:0] o_m_axi_arcache;
	wire [2:0] o_m_axi_arprot;
	wire o_m_axi_arvalid;
	logic i_m_axi_arready;

	logic [31:0] i_m_axi_rdata;
	logic [1:0] i_m_axi_rresp;
	logic i_m_axi_rlast;
	logic i_m_axi_rvalid;
	wire o_m_axi_rready;

	// AXI master write
	wire [3:0] o_m_axi_awid;
	wire [31:0] o_m_axi_awaddr;
	wire [7:0] o_m_axi_awlen;
	wire [2:0] o_m_axi_awsize;
	wire [1:0] o_m_axi_awburst;
	wire o_m_axi_awlock;
	wire [3:0] o_m_axi_awcache;
	wire [2:0] o_m_axi_awprot;
	wire o_m_axi_awvalid;
	logic i_m_axi_awready;

	wire [31:0] o_m_axi_wdata;
	wire [3:0] o_m_axi_wstrb;
	wire o_m_axi_wlast;
	wire o_m_axi_wvalid;
	logic i_m_axi_wready;

	logic [1:0] i_m_axi_bresp;
	logic i_m_axi_bvalid;
	wire o_m_axi_bready;

	always #5 clk = ~clk;

	top #(
		.AXI_ADDR_W(32),
		.AXI_DATA_W(32)
	) dut (
		.clk(clk),
		.rstn(rstn),

		// AXI-Lite slave
		.i_s_axil_awaddr(i_s_axil_awaddr),
		.i_s_axil_awvalid(i_s_axil_awvalid),
		.o_s_axil_awready(o_s_axil_awready),

		.i_s_axil_wdata(i_s_axil_wdata),
		.i_s_axil_wstrb(i_s_axil_wstrb),
		.i_s_axil_wvalid(i_s_axil_wvalid),
		.o_s_axil_wready(o_s_axil_wready),

		.o_s_axil_bresp(o_s_axil_bresp),
		.o_s_axil_bvalid(o_s_axil_bvalid),
		.i_s_axil_bready(i_s_axil_bready),

		.i_s_axil_araddr(i_s_axil_araddr),
		.i_s_axil_arvalid(i_s_axil_arvalid),
		.o_s_axil_arready(o_s_axil_arready),

		.o_s_axil_rdata(o_s_axil_rdata),
		.o_s_axil_rresp(o_s_axil_rresp),
		.o_s_axil_rvalid(o_s_axil_rvalid),
		.i_s_axil_rready(i_s_axil_rready),

		// AXI master read
		.o_m_axi_arid(o_m_axi_arid),
		.o_m_axi_araddr(o_m_axi_araddr),
		.o_m_axi_arlen(o_m_axi_arlen),
		.o_m_axi_arsize(o_m_axi_arsize),
		.o_m_axi_arburst(o_m_axi_arburst),
		.o_m_axi_arlock(o_m_axi_arlock),
		.o_m_axi_arcache(o_m_axi_arcache),
		.o_m_axi_arprot(o_m_axi_arprot),
		.o_m_axi_arvalid(o_m_axi_arvalid),
		.i_m_axi_arready(i_m_axi_arready),

		.i_m_axi_rdata(i_m_axi_rdata),
		.i_m_axi_rresp(i_m_axi_rresp),
		.i_m_axi_rlast(i_m_axi_rlast),
		.i_m_axi_rvalid(i_m_axi_rvalid),
		.o_m_axi_rready(o_m_axi_rready),

		// AXI master write
		.o_m_axi_awid(o_m_axi_awid),
		.o_m_axi_awaddr(o_m_axi_awaddr),
		.o_m_axi_awlen(o_m_axi_awlen),
		.o_m_axi_awsize(o_m_axi_awsize),
		.o_m_axi_awburst(o_m_axi_awburst),
		.o_m_axi_awlock(o_m_axi_awlock),
		.o_m_axi_awcache(o_m_axi_awcache),
		.o_m_axi_awprot(o_m_axi_awprot),
		.o_m_axi_awvalid(o_m_axi_awvalid),
		.i_m_axi_awready(i_m_axi_awready),

		.o_m_axi_wdata(o_m_axi_wdata),
		.o_m_axi_wstrb(o_m_axi_wstrb),
		.o_m_axi_wlast(o_m_axi_wlast),
		.o_m_axi_wvalid(o_m_axi_wvalid),
		.i_m_axi_wready(i_m_axi_wready),

		.i_m_axi_bresp(i_m_axi_bresp),
		.i_m_axi_bvalid(i_m_axi_bvalid),
		.o_m_axi_bready(o_m_axi_bready)
	);


	task dut_rst;
		rstn = 0;
		repeat(4) @(posedge clk);
		@(negedge clk);
		rstn = 1;
	endtask


	task automatic init;
		clk = 0;
		rstn = 0;
			
		i_s_axil_awaddr = '0;
		i_s_axil_awvalid = 0;
		i_s_axil_wdata = '0;
		i_s_axil_wstrb = '0;
		i_s_axil_wvalid = 0;
		i_s_axil_bready = 0;
		i_s_axil_araddr = '0;
		i_s_axil_arvalid = 0;
		i_s_axil_rready = 0;

		i_m_axi_arready = 0;
		i_m_axi_rdata = '0;
		i_m_axi_rresp = 0;
		i_m_axi_rlast = 0;

		i_m_axi_rvalid = 0;
		i_m_axi_awready = 0;
		i_m_axi_wready = 0;
		i_m_axi_bresp = 0;
		i_m_axi_bvalid = 0;
	endtask


	task axil_write(
		input logic [7:0] addr,
		input logic [31:0] data
	);
		begin
			@(posedge clk);
			i_s_axil_awaddr = addr;
			i_s_axil_awvalid = 1;
			i_s_axil_wdata = data;
			i_s_axil_wstrb = 4'hF;
			i_s_axil_wvalid = 1;
			wait (o_s_axil_awready && o_s_axil_wready);
			@(posedge clk);
			i_s_axil_wvalid = 0;
			i_s_axil_wvalid = 0;
			i_s_axil_bready = 1;
			wait (o_s_axil_bvalid);
			@(posedge clk);
			i_s_axil_bready = 0;
		end
	endtask

	task axil_read(
		input logic [7:0] addr,
		output logic [31:0] data
	);
		begin
			@(posedge clk);
			i_s_axil_araddr = addr;
			i_s_axil_arvalid = 1;
			wait (o_s_axil_arready);
			@(posedge clk);
			i_s_axil_arvalid = 0;
			i_s_axil_rready = 1;
			wait(o_s_axil_rvalid);
			@(posedge clk);
			i_s_axil_rready = 0;
		end
	endtask

	logic [31:0] axil_rd_data;
	initial begin
		init();
		dut_rst();

		axil_write(8'h00, 32'h12345678);
		axil_read(8'h00, axil_rd_data);

		$display("READ = %0h", axil_rd_data);
		
		$finish;
	end
endmodule
