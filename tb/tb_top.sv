`timescale 1ps/1ps
`include "vectors/tb_params.vh"

module tb_top;
	localparam int MEM_WORDS = `TB_MEM_WORDS;

	logic clk, rstn;
	logic [7:0]  i_s_axil_awaddr, i_s_axil_araddr;
	logic i_s_axil_awvalid, i_s_axil_wvalid, i_s_axil_bready;
	logic i_s_axil_arvalid, i_s_axil_rready;
	logic [31:0] i_s_axil_wdata;
	logic [3:0]  i_s_axil_wstrb;
	wire o_s_axil_awready, o_s_axil_wready, o_s_axil_bvalid;
	wire o_s_axil_arready, o_s_axil_rvalid;
	wire [1:0] o_s_axil_bresp, o_s_axil_rresp;
	wire [31:0] o_s_axil_rdata;
	wire [31:0] o_m_axi_araddr, o_m_axi_awaddr, o_m_axi_wdata;
	wire [7:0]  o_m_axi_arlen;
	wire o_m_axi_arvalid, o_m_axi_rready, o_m_axi_awvalid;
	wire o_m_axi_wvalid, o_m_axi_wlast, o_m_axi_bready;
	logic i_m_axi_arready, i_m_axi_rvalid, i_m_axi_rlast;
	logic i_m_axi_awready, i_m_axi_wready, i_m_axi_bvalid;
	logic [31:0] i_m_axi_rdata;
	logic [1:0] i_m_axi_rresp, i_m_axi_bresp;

	always #(`TB_CLK_HALF) clk = ~clk;

`ifdef GL
	top dut (
`else
	top #(.AXI_ADDR_W(`TB_AXI_ADDR_W), .AXI_DATA_W(`TB_AXI_DATA_W)) dut (
`endif
		.clk(clk), .rstn(rstn),
		.i_s_axil_awaddr(i_s_axil_awaddr), .i_s_axil_awvalid(i_s_axil_awvalid),
		.o_s_axil_awready(o_s_axil_awready),
		.i_s_axil_wdata(i_s_axil_wdata), .i_s_axil_wstrb(i_s_axil_wstrb),
		.i_s_axil_wvalid(i_s_axil_wvalid), .o_s_axil_wready(o_s_axil_wready),
		.o_s_axil_bresp(o_s_axil_bresp), .o_s_axil_bvalid(o_s_axil_bvalid),
		.i_s_axil_bready(i_s_axil_bready),
		.i_s_axil_araddr(i_s_axil_araddr), .i_s_axil_arvalid(i_s_axil_arvalid),
		.o_s_axil_arready(o_s_axil_arready),
		.o_s_axil_rdata(o_s_axil_rdata), .o_s_axil_rresp(o_s_axil_rresp),
		.o_s_axil_rvalid(o_s_axil_rvalid), .i_s_axil_rready(i_s_axil_rready),
		.o_m_axi_araddr(o_m_axi_araddr), .o_m_axi_arlen(o_m_axi_arlen),
		.o_m_axi_arvalid(o_m_axi_arvalid), .i_m_axi_arready(i_m_axi_arready),
		.i_m_axi_rdata(i_m_axi_rdata), .i_m_axi_rresp(i_m_axi_rresp),
		.i_m_axi_rlast(i_m_axi_rlast), .i_m_axi_rvalid(i_m_axi_rvalid),
		.o_m_axi_rready(o_m_axi_rready),
		.o_m_axi_awaddr(o_m_axi_awaddr), .o_m_axi_awvalid(o_m_axi_awvalid),
		.i_m_axi_awready(i_m_axi_awready),
		.o_m_axi_wdata(o_m_axi_wdata), .o_m_axi_wlast(o_m_axi_wlast),
		.o_m_axi_wvalid(o_m_axi_wvalid), .i_m_axi_wready(i_m_axi_wready),
		.i_m_axi_bresp(i_m_axi_bresp), .i_m_axi_bvalid(i_m_axi_bvalid),
		.o_m_axi_bready(o_m_axi_bready)
	);

	int errors, checks, stored_bursts;
	string phase;
	logic [31:0] mem [0:MEM_WORDS-1];
	logic [31:0] gold [0:`TB_GOLD_WORDS-1];

	task automatic fail(input string msg);
		errors++;
		$display("[%0t] FAIL (%s): %s", $time, phase, msg);
	endtask

	task automatic expect_eq(input string name, input logic [31:0] got, input logic [31:0] exp);
		checks++;
		if (got !== exp) fail($sformatf("%s=%08h exp %08h", name, got, exp));
	endtask

	function automatic int mem_idx(input logic [31:0] a);
		return int'((a >> 2) & 32'(MEM_WORDS - 1));
	endfunction

	function automatic logic [31:0] ctrl(input bit en, go, load_w, store, auto_st, auto_fill);
		return (32'(en) << `TB_CTRL_EN) | (32'(go) << `TB_CTRL_GO) |
		       (32'(load_w) << `TB_CTRL_LOAD_W) | (32'(store) << `TB_CTRL_STORE) |
		       (32'(auto_st) << `TB_CTRL_AUTO_ST) | (32'(auto_fill) << `TB_CTRL_AUTO_FILL);
	endfunction

	task automatic load_vectors;
		string stim_file, gold_file;
		if (!$value$plusargs("stim=%s", stim_file)) stim_file = "tb/vectors/stim.hex";
		if (!$value$plusargs("gold=%s", gold_file)) gold_file = "tb/vectors/golden.hex";
		$readmemh(stim_file, mem, mem_idx(`TB_SRC_BASE),
		          mem_idx(`TB_SRC_BASE) + `TB_STIM_WORDS - 1);
		$readmemh(gold_file, gold);
	endtask

	task automatic clear_region(input logic [31:0] base, input int words);
		int i;
		for (i = 0; i < words; i++) mem[mem_idx(base + 32'(4 * i))] = '0;
	endtask

	task automatic check_tiles(input logic [31:0] base);
		int t, w;
		for (t = 0; t < `TB_TILES; t++)
			for (w = 0; w < `TB_TILE_BEATS; w++) begin
				checks++;
				if (mem[mem_idx(base + 32'(4 * (t * `TB_TILE_BEATS + w)))] !==
				    gold[t * `TB_TILE_BEATS + w])
					fail($sformatf("tile%0d w%0d", t, w));
			end
	endtask

	// AXI read slave
	logic rs_busy;
	logic [31:0] rs_addr;
	int rs_idx, rs_beats;
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rs_busy <= 0; i_m_axi_arready <= 1; i_m_axi_rvalid <= 0;
			i_m_axi_rlast <= 0; i_m_axi_rdata <= '0; i_m_axi_rresp <= '0;
		end else if (!rs_busy) begin
			if (o_m_axi_arvalid && i_m_axi_arready) begin
				rs_addr <= o_m_axi_araddr; rs_beats <= int'(o_m_axi_arlen) + 1;
				rs_idx <= 1; i_m_axi_arready <= 0;
				i_m_axi_rdata <= mem[mem_idx(o_m_axi_araddr)];
				i_m_axi_rvalid <= 1; i_m_axi_rlast <= (o_m_axi_arlen == 0);
				rs_busy <= 1;
			end
		end else if (o_m_axi_rready) begin
			if (i_m_axi_rlast) begin
				i_m_axi_rvalid <= 0; i_m_axi_rlast <= 0;
				i_m_axi_arready <= 1; rs_busy <= 0;
			end else begin
				i_m_axi_rdata <= mem[mem_idx(rs_addr + 32'(4 * rs_idx))];
				i_m_axi_rlast <= (rs_idx == rs_beats - 1);
				rs_idx <= rs_idx + 1;
			end
		end
	end

	// AXI write slave
	logic [1:0] ws;
	logic [31:0] ws_addr;
	int ws_idx;
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			ws <= 0; i_m_axi_awready <= 1; i_m_axi_wready <= 0;
			i_m_axi_bvalid <= 0; i_m_axi_bresp <= '0; stored_bursts <= 0;
		end else unique case (ws)
			2'd0: if (o_m_axi_awvalid && i_m_axi_awready) begin
				ws_addr <= o_m_axi_awaddr; ws_idx <= 0;
				i_m_axi_awready <= 0; i_m_axi_wready <= 1; ws <= 1;
			end
			2'd1: if (o_m_axi_wvalid && i_m_axi_wready) begin
				mem[mem_idx(ws_addr + 32'(4 * ws_idx))] <= o_m_axi_wdata;
				if (ws_idx == `TB_TILE_BEATS - 1) begin
					i_m_axi_wready <= 0; i_m_axi_bvalid <= 1; ws <= 2;
				end else ws_idx <= ws_idx + 1;
			end
			default: if (o_m_axi_bready) begin
				i_m_axi_bvalid <= 0; i_m_axi_awready <= 1;
				stored_bursts <= stored_bursts + 1; ws <= 0;
			end
		endcase
	end

`ifndef GL
	logic prev_cs, prev_ovf;
	always @(posedge clk) if (rstn) begin
		if (dut.u_sram.i_swap && (dut.u_sram.i_cs_array || prev_cs))
			fail("swap/read collide");
		if (dut.fifo_overflow && !prev_ovf) fail("fifo overflow");
		prev_cs <= dut.u_sram.i_cs_array;
		prev_ovf <= dut.fifo_overflow;
	end
`endif

	task automatic dut_rst;
		rstn = 0; repeat (4) @(posedge clk);
		@(negedge clk); rstn = 1; repeat (12) @(posedge clk);
	endtask

	task automatic axil_write(input logic [7:0] addr, input logic [31:0] data);
		bit aw_done, w_done;
		@(posedge clk);
		i_s_axil_awaddr <= addr; i_s_axil_awvalid <= 1;
		i_s_axil_wdata <= data; i_s_axil_wstrb <= 4'hF;
		i_s_axil_wvalid <= 1; i_s_axil_bready <= 1;
		aw_done = 0; w_done = 0;
		while (!(aw_done && w_done)) begin
			@(posedge clk);
			if (!aw_done && o_s_axil_awready) begin i_s_axil_awvalid <= 0; aw_done = 1; end
			if (!w_done && o_s_axil_wready) begin i_s_axil_wvalid <= 0; w_done = 1; end
		end
		while (!o_s_axil_bvalid) @(posedge clk);
		if (o_s_axil_bresp !== 2'b00) fail("bresp");
		@(posedge clk); i_s_axil_bready <= 0;
	endtask

	task automatic axil_read(input logic [7:0] addr, output logic [31:0] data);
		bit ar_done;
		@(posedge clk);
		i_s_axil_araddr <= addr; i_s_axil_arvalid <= 1; i_s_axil_rready <= 1;
		ar_done = 0;
		while (!ar_done) begin
			@(posedge clk);
			if (o_s_axil_arready) begin i_s_axil_arvalid <= 0; ar_done = 1; end
		end
		while (!o_s_axil_rvalid) @(posedge clk);
		data = o_s_axil_rdata;
		if (o_s_axil_rresp !== 2'b00) fail("rresp");
		@(posedge clk); i_s_axil_rready <= 0;
	endtask

	task automatic status(output logic [31:0] s);
		axil_read(`TB_REG_STATUS, s);
		if (s[`TB_ST_DMA_ERR] || s[`TB_ST_WDMA_ERR] || s[`TB_ST_RES_OVF])
			fail($sformatf("STATUS=%08h", s));
	endtask

	task automatic wait_bit(input int idx, input bit val, input int tries);
		logic [31:0] s; int n; bit done;
		n = 0; done = 0;
		while (!done && n < tries) begin
			status(s);
			if (s[idx] === val) done = 1;
			else begin @(posedge clk); n++; end
		end
		if (!done) fail("wait_bit timeout");
	endtask

	task automatic wait_tiles(input int n);
		logic [31:0] s; int seen, prev, cnt, i;
		seen = 0; prev = 0;
		for (i = 0; i < 400 * n + 4000; i++) begin
			status(s);
			cnt = int'((s >> `TB_ST_TILE_LSB) & 32'hF);
			seen += (cnt - prev) & 32'hF;
			prev = cnt;
			if (seen >= n) return;
			@(posedge clk);
		end
		fail($sformatf("tiles %0d/%0d", seen, n));
	endtask

	task automatic test_csr_smoke;
		logic [31:0] d;
		phase = "csr";
		axil_read(`TB_REG_CTRL, d); expect_eq("CTRL", d, 0);
		axil_write(`TB_REG_SRC_ADDR, 32'h12345678);
		axil_read(`TB_REG_SRC_ADDR, d); expect_eq("SRC", d, 32'h12345678);
		axil_write(`TB_REG_LEN, 32'hFFFFFFFF);
		axil_read(`TB_REG_LEN, d); expect_eq("LEN", d, `TB_LEN_MASK);
		axil_write(`TB_REG_NJOBS, 32'hFFFFFFFF);
		axil_read(`TB_REG_NJOBS, d); expect_eq("NJOBS", d, `TB_NJOBS_MASK);
	endtask

	task automatic test_bad_descriptor;
		logic [31:0] s;
		phase = "bad_desc";
		axil_write(`TB_REG_SRC_ADDR, `TB_SRC_BASE);
		axil_write(`TB_REG_LEN, 0);
		axil_write(`TB_REG_CTRL, ctrl(1, 0, 1, 0, 0, 0));
		axil_write(`TB_REG_CTRL, ctrl(1, 1, 1, 0, 0, 0));
		repeat (20) @(posedge clk);
		axil_read(`TB_REG_STATUS, s);
		checks++;
		if (!s[`TB_ST_DMA_ERR]) fail("DMA_ERR missing");
	endtask

	// Primary path: same stim/golden as cocotb test_generated_stream
	task automatic test_generated_stream;
		phase = "gen_stream";
		clear_region(`TB_ALT_DST, `TB_TILES * `TB_TILE_BEATS);
		axil_write(`TB_REG_CTRL, ctrl(1, 0, 0, 0, 0, 0));
		axil_write(`TB_REG_DST_ADDR, `TB_ALT_DST);
		axil_write(`TB_REG_SRC_ADDR, `TB_SRC_BASE);
		axil_write(`TB_REG_LEN, `TB_WEIGHTS_JOB);
		axil_write(`TB_REG_NJOBS, `TB_TILES - 1);
		axil_write(`TB_REG_CTRL, ctrl(1, 0, 1, 0, 1, 0));
		axil_write(`TB_REG_CTRL, ctrl(1, 1, 1, 0, 1, 0));
		wait_bit(`TB_ST_W_VALID, 1, 500);
		wait_bit(`TB_ST_CTRL_BUSY, 0, 500);
		axil_write(`TB_REG_SRC_ADDR, `TB_SRC_BASE + 32'(4 * `TB_WEIGHTS_JOB));
		axil_write(`TB_REG_LEN, `TB_TILE_WORDS);
		axil_write(`TB_REG_CTRL, ctrl(1, 0, 0, 0, 1, 1));
		wait_tiles(`TB_TILES);
		check_tiles(`TB_ALT_DST);
		checks++;
		if (stored_bursts < `TB_TILES) fail("burst count");
	endtask

	initial begin
		#(`TB_WATCHDOG);
		$fatal(1, "watchdog @ %s", phase);
	end

	initial begin
		string wave_file;
		if (!$value$plusargs("wave=%s", wave_file)) wave_file = "tb_top.vcd";
		$dumpfile(wave_file);
`ifdef GL
		$dumpvars(1, tb_top);
`else
		$dumpvars(0, tb_top);
`endif
		errors = 0; checks = 0; phase = "init";
		clk = 0; rstn = 0;
		{i_s_axil_awaddr, i_s_axil_araddr, i_s_axil_wdata} = '0;
		{i_s_axil_awvalid, i_s_axil_wvalid, i_s_axil_bready} = '0;
		{i_s_axil_arvalid, i_s_axil_rready, i_s_axil_wstrb} = '0;
		load_vectors();
		dut_rst();
		test_csr_smoke();
		dut_rst();
		test_bad_descriptor();
		dut_rst();
		load_vectors();
		test_generated_stream();
		repeat (10) @(posedge clk);
		if (errors) $fatal(1, "tb_top FAIL %0d/%0d", errors, checks);
		$display("tb_top: PASS (%0d checks)", checks);
		$finish;
	end
endmodule
