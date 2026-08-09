`timescale 1ps/1ps
`include "vectors/tb_params.vh"

module tb_top;

	localparam int MATRIX_SIZE = `TB_MATRIX_SIZE;
	localparam int DATA_WIDTH = `TB_DATA_WIDTH;
	localparam int RESULT_W = `TB_RESULT_W;
	localparam int TILE_BEATS = `TB_TILE_BEATS;
	localparam int TILE_BYTES = `TB_TILE_BYTES;
	localparam int TILE_WORDS = `TB_TILE_WORDS;
	localparam int WEIGHTS_JOB = `TB_WEIGHTS_JOB;
	localparam int LEVEL_W = `TB_LEVEL_W;
	localparam int ST_TILE_LSB = `TB_ST_TILE_LSB;
	localparam int TILES = `TB_TILES;
	localparam int STIM_WORDS = `TB_STIM_WORDS;
	localparam int GOLD_WORDS = `TB_GOLD_WORDS;

	localparam logic [7:0] REG_CTRL = 8'h00;
	localparam logic [7:0] REG_STATUS = 8'h04;
	localparam logic [7:0] REG_SRC_ADDR = 8'h08;
	localparam logic [7:0] REG_LEN = 8'h0C;
	localparam logic [7:0] REG_RESULT = 8'h10;
	localparam logic [7:0] REG_DST_ADDR = 8'h14;
	localparam logic [7:0] REG_NJOBS = 8'h18;

	// CTRL bits
	localparam int CTRL_EN = 0;
	localparam int CTRL_GO = 1;
	localparam int CTRL_LOAD_W = 2;
	localparam int CTRL_STORE = 3;
	localparam int CTRL_AUTO_ST = 4;
	localparam int CTRL_AUTO_FILL = 5;

	// STATUS bits
	localparam int ST_DMA_BUSY = 0;
	localparam int ST_DMA_ERR = 2;
	localparam int ST_CTRL_BUSY = 4;
	localparam int ST_W_VALID = 8;
	localparam int ST_RES_OVF = 10;
	localparam int ST_WDMA_DONE = 12;
	localparam int ST_WDMA_ERR = 13;
	localparam int ST_LEVEL_LSB = 16;

	localparam int MEM_WORDS = 4096;
	localparam logic [31:0] SRC_BASE = 32'h0000_1000;
	localparam logic [31:0] DST_BASE = 32'h0000_2000;
	localparam logic [31:0] ALT_DST = 32'h0000_3000;

	localparam time CLK_HALF = 5000;
	localparam time WATCHDOG = 500_000_000;

	logic clk;
	logic rstn;

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

	always #CLK_HALF clk = ~clk;

	top #(
		.AXI_ADDR_W(32),
		.AXI_DATA_W(32)
	) dut (
		.clk(clk),
		.rstn(rstn),

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

	int errors;
	int checks;
	string phase;

	task automatic fail(input string msg);
		errors++;
		$display("[%0t] FAIL (%s): %s", $time, phase, msg);
	endtask

	task automatic expect_eq(input string name, input logic [31:0] got, input logic [31:0] exp);
		begin
			checks++;
			if (got !== exp) fail($sformatf("%s = %08h, expected %08h", name, got, exp));
		end
	endtask

	logic [31:0] mem [0:MEM_WORDS-1];
	logic [31:0] gold [0:GOLD_WORDS-1];

	function automatic int mem_idx(input logic [31:0] byte_addr);
		return int'((byte_addr >> 2) & 32'(MEM_WORDS - 1));
	endfunction

	string stim_file, gold_file;

	task automatic load_vectors;
		begin
			if (!$value$plusargs("stim=%s", stim_file)) stim_file = "tb/vectors/stim.hex";
			if (!$value$plusargs("gold=%s", gold_file)) gold_file = "tb/vectors/golden.hex";
			$readmemh(stim_file, mem, mem_idx(SRC_BASE), mem_idx(SRC_BASE) + STIM_WORDS - 1);
			$readmemh(gold_file, gold);
		end
	endtask

	task automatic clear_region(input logic [31:0] base, input int words);
		int i;
		begin
			for (i = 0; i < words; i++) mem[mem_idx(base + 32'(4 * i))] = 32'h0;
		end
	endtask

	task automatic check_tile(input string label, input int t, input logic [31:0] base);
		int w;
		logic [31:0] got, exp;
		begin
			for (w = 0; w < TILE_BEATS; w++) begin
				got = mem[mem_idx(base + 32'(4 * ((t * TILE_BEATS) + w)))];
				exp = gold[(t * TILE_BEATS) + w];
				checks++;
				if (got !== exp)
					fail($sformatf("%s tile %0d word %0d = %08h, expected %08h", label, t, w, got, exp));
			end
		end
	endtask

	localparam int RS_IDLE = 0, RS_DATA = 1;
	logic rs_state;
	logic [31:0] rs_addr;
	int rs_idx, rs_beats;

	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rs_state <= RS_IDLE;
			i_m_axi_arready <= 1'b1;
			i_m_axi_rvalid <= 1'b0;
			i_m_axi_rlast <= 1'b0;
			i_m_axi_rdata <= 32'h0;
			i_m_axi_rresp <= 2'b00;
			rs_idx <= 0;
			rs_beats <= 0;
			rs_addr <= 32'h0;
		end else begin
			case (rs_state)
				RS_IDLE: begin
					if (o_m_axi_arvalid && i_m_axi_arready) begin
						rs_addr <= o_m_axi_araddr;
						rs_beats <= int'(o_m_axi_arlen) + 1;
						rs_idx <= 1;
						i_m_axi_arready <= 1'b0;
						i_m_axi_rdata <= mem[mem_idx(o_m_axi_araddr)];
						i_m_axi_rvalid <= 1'b1;
						i_m_axi_rlast <= (o_m_axi_arlen == 8'd0);
						rs_state <= RS_DATA;
					end
				end
				RS_DATA: begin
					if (o_m_axi_rready) begin
						if (i_m_axi_rlast) begin
							i_m_axi_rvalid <= 1'b0;
							i_m_axi_rlast <= 1'b0;
							i_m_axi_arready <= 1'b1;
							rs_state <= RS_IDLE;
						end else begin
							i_m_axi_rdata <= mem[mem_idx(rs_addr + 32'(4 * rs_idx))];
							i_m_axi_rlast <= (rs_idx == (rs_beats - 1));
							rs_idx <= rs_idx + 1;
						end
					end
				end
			endcase
		end
	end

	localparam int WS_IDLE = 0, WS_DATA = 1, WS_RESP = 2;
	logic [1:0] ws_state;
	logic [31:0] ws_addr;
	int ws_idx, ws_beats;
	int stored_bursts;

	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			ws_state <= WS_IDLE;
			i_m_axi_awready <= 1'b1;
			i_m_axi_wready <= 1'b0;
			i_m_axi_bvalid <= 1'b0;
			i_m_axi_bresp <= 2'b00;
			ws_idx <= 0;
			ws_beats <= 0;
			ws_addr <= 32'h0;
			stored_bursts <= 0;
		end else begin
			case (ws_state)
				WS_IDLE: begin
					if (o_m_axi_awvalid && i_m_axi_awready) begin
						ws_addr <= o_m_axi_awaddr;
						ws_beats <= int'(o_m_axi_awlen) + 1;
						ws_idx <= 0;
						i_m_axi_awready <= 1'b0;
						i_m_axi_wready <= 1'b1;
						ws_state <= WS_DATA;
					end
				end
				WS_DATA: begin
					if (o_m_axi_wvalid && i_m_axi_wready) begin
						mem[mem_idx(ws_addr + 32'(4 * ws_idx))] <= o_m_axi_wdata;
						if ((o_m_axi_wlast === 1'b1) != (ws_idx == (ws_beats - 1)))
							fail($sformatf("wlast=%b at beat %0d of %0d", o_m_axi_wlast,
							               ws_idx, ws_beats));
						if (ws_idx == (ws_beats - 1)) begin
							i_m_axi_wready <= 1'b0;
							i_m_axi_bvalid <= 1'b1;
							ws_state <= WS_RESP;
						end else begin
							ws_idx <= ws_idx + 1;
						end
					end
				end
				WS_RESP: begin
					if (o_m_axi_bready) begin
						i_m_axi_bvalid <= 1'b0;
						i_m_axi_awready <= 1'b1;
						stored_bursts <= stored_bursts + 1;
						ws_state <= WS_IDLE;
					end
				end
			endcase
		end
	end

	logic prev_cs_array, prev_ovf;
	always @(posedge clk) begin
		if (!rstn) begin
			prev_cs_array <= 1'b0;
			prev_ovf <= 1'b0;
		end else begin
			
			if (o_m_axi_arvalid) begin
				if (o_m_axi_arsize !== 3'b010) fail("arsize is not 4 bytes/beat");
				if (o_m_axi_arburst !== 2'b01) fail("arburst is not INCR");
			end
			
			if (o_m_axi_awvalid) begin
				if (o_m_axi_awlen !== 8'(TILE_BEATS - 1))
					fail($sformatf("awlen=%0d, expected %0d", o_m_axi_awlen, TILE_BEATS - 1));
				if (o_m_axi_awsize !== 3'b010) fail("awsize is not 4 bytes/beat");
				if (o_m_axi_awburst !== 2'b01) fail("awburst is not INCR");
				if (o_m_axi_awaddr[1:0] !== 2'b00) fail("awaddr is not word aligned");
			end
			
			if (o_m_axi_wvalid && i_m_axi_wready && (o_m_axi_wstrb !== 4'hF))
				fail($sformatf("wstrb=%h, expected a full word", o_m_axi_wstrb));

			if (dut.u_sram.i_swap && (dut.u_sram.i_cs_array || prev_cs_array))
				fail("i_swap collided with an array read");
			if (dut.fifo_overflow && !prev_ovf) fail("result fifo overflowed");
			prev_cs_array <= dut.u_sram.i_cs_array;
			prev_ovf <= dut.fifo_overflow;
		end
	end

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
	endtask

	task automatic dut_rst;
		begin
			rstn = 0;
			repeat (4) @(posedge clk);
			@(negedge clk);
			rstn = 1;
			repeat (8) @(posedge clk);
		end
	endtask

	task automatic axil_write(input logic [7:0] addr, input logic [31:0] data);
		bit aw_done, w_done;
		begin
			@(posedge clk);
			i_s_axil_awaddr <= addr;
			i_s_axil_awvalid <= 1;
			i_s_axil_wdata <= data;
			i_s_axil_wstrb <= 4'hF;
			i_s_axil_wvalid <= 1;
			i_s_axil_bready <= 1;
			aw_done = 0;
			w_done = 0;
			while (!(aw_done && w_done)) begin
				@(posedge clk);
				if (!aw_done && o_s_axil_awready) begin
					i_s_axil_awvalid <= 0;
					aw_done = 1;
				end
				if (!w_done && o_s_axil_wready) begin
					i_s_axil_wvalid <= 0;
					w_done = 1;
				end
			end
			while (!o_s_axil_bvalid) @(posedge clk);
			if (o_s_axil_bresp !== 2'b00)
				fail($sformatf("bresp=%0d writing %02h", o_s_axil_bresp, addr));
			@(posedge clk);
			i_s_axil_bready <= 0;
		end
	endtask

	task automatic axil_read(input logic [7:0] addr, output logic [31:0] data);
		bit ar_done;
		begin
			@(posedge clk);
			i_s_axil_araddr <= addr;
			i_s_axil_arvalid <= 1;
			i_s_axil_rready <= 1;
			ar_done = 0;
			while (!ar_done) begin
				@(posedge clk);
				if (o_s_axil_arready) begin
					i_s_axil_arvalid <= 0;
					ar_done = 1;
				end
			end
			while (!o_s_axil_rvalid) @(posedge clk);
			data = o_s_axil_rdata;
			if (o_s_axil_rresp !== 2'b00)
				fail($sformatf("rresp=%0d reading %02h", o_s_axil_rresp, addr));
			@(posedge clk);
			i_s_axil_rready <= 0;
		end
	endtask

	task automatic read_status(output logic [31:0] s);
		begin
			axil_read(REG_STATUS, s);
			if (s[ST_DMA_ERR]) fail($sformatf("read dma error, STATUS=%08h", s));
			if (s[ST_WDMA_ERR]) fail($sformatf("write dma error, STATUS=%08h", s));
			if (s[ST_RES_OVF]) fail($sformatf("result fifo overflow, STATUS=%08h", s));
		end
	endtask

	task automatic wait_bit(input int idx, input bit val, input string what,
	                        input int tries);
		logic [31:0] s;
		int n;
		bit done;
		begin
			n = 0;
			done = 0;
			while (!done && (n < tries)) begin
				read_status(s);
				if (s[idx] === val) done = 1;
				else begin
					@(posedge clk);
					n++;
				end
			end
			if (!done) fail($sformatf("timed out waiting for %s", what));
		end
	endtask

	task automatic wait_level(input int count, input int tries);
		logic [31:0] s;
		int n;
		bit done;
		begin
			n = 0;
			done = 0;
			while (!done && (n < tries)) begin
				read_status(s);
				if (int'((s >> ST_LEVEL_LSB) & 32'((1 << LEVEL_W) - 1)) >= count) done = 1;
				else begin
					@(posedge clk);
					n++;
				end
			end
			if (!done) fail($sformatf("timed out waiting for %0d results", count));
		end
	endtask

	task automatic wait_tiles(input int n, input int tries);
		logic [31:0] s;
		int seen, prev, cnt, i;
		bit done;
		begin
			seen = 0;
			prev = 0;
			i = 0;
			done = 0;
			while (!done && (i < tries)) begin
				read_status(s);
				cnt = int'((s >> ST_TILE_LSB) & 32'hF);
				seen = seen + ((cnt - prev) & 32'hF);
				prev = cnt;
				if (seen >= n) done = 1;
				else begin
					@(posedge clk);
					i++;
				end
			end
			if (!done) fail($sformatf("only %0d/%0d tiles stored", seen, n));
		end
	endtask

	function automatic logic [31:0] ctrl_bits(input bit en, input bit go, input bit load_w, input bit store, input bit auto_st, input bit auto_fill);
		return (32'(en) << CTRL_EN) | (32'(go) << CTRL_GO) | (32'(load_w) << CTRL_LOAD_W) | (32'(store) << CTRL_STORE) | (32'(auto_st) << CTRL_AUTO_ST) 
			| (32'(auto_fill) << CTRL_AUTO_FILL);
	endfunction

	// program one fill descriptor and pulse GO
	task automatic launch_fill(input int words, input bit load_w, input logic [31:0] src);
		logic [31:0] base;
		begin
			base = ctrl_bits(1, 0, load_w, 0, 0, 0);
			axil_write(REG_SRC_ADDR, src);
			axil_write(REG_LEN, 32'(words));
			axil_write(REG_CTRL, base);
			axil_write(REG_CTRL, base | (32'h1 << CTRL_GO));
		end
	endtask

	
	task automatic check_geometry;
		begin
			phase = "geometry";
			expect_eq("MATRIX_SIZE", 32'(dut.MATRIX_SIZE), 32'(MATRIX_SIZE));
			expect_eq("DATA_WIDTH", 32'(dut.DATA_WIDTH), 32'(DATA_WIDTH));
			expect_eq("RESULT_W", 32'(dut.RESULT_W), 32'(RESULT_W));
			expect_eq("TILE_BEATS", 32'(dut.TILE_BEATS), 32'(TILE_BEATS));
			expect_eq("TILE_BYTES", 32'(dut.TILE_BYTES), 32'(TILE_BYTES));
			expect_eq("LEVEL_W", 32'(dut.LEVEL_W), 32'(LEVEL_W));
			expect_eq("ST_TILE_LSB", 32'(dut.ST_TILE_LSB), 32'(ST_TILE_LSB));
			expect_eq("golden image size", 32'(GOLD_WORDS), 32'(TILES * TILE_BEATS));
			expect_eq("stim image size", 32'(STIM_WORDS), 32'(WEIGHTS_JOB + ((TILES - 1) * TILE_WORDS)));
		end
	endtask

	task automatic test_csr_reset;
		logic [31:0] d;
		begin
			phase = "csr_reset";
			axil_read(REG_CTRL, d);
			expect_eq("CTRL after reset", d, 32'h0);
			axil_read(REG_SRC_ADDR, d);
			expect_eq("SRC_ADDR after reset", d, 32'h0);
			axil_read(REG_LEN, d);
			expect_eq("LEN after reset", d, 32'h0);
			axil_read(REG_DST_ADDR, d);
			expect_eq("DST_ADDR after reset", d, 32'h0);
			axil_read(REG_NJOBS, d);
			expect_eq("NJOBS after reset", d, 32'h0);
			axil_read(REG_STATUS, d);
			expect_eq("STATUS after reset", d, 32'h0);
		end
	endtask

	task automatic test_csr_readback;
		logic [31:0] d;
		begin
			phase = "csr_readback";
			axil_write(REG_SRC_ADDR, 32'h1234_5678);
			axil_read(REG_SRC_ADDR, d);
			expect_eq("SRC_ADDR", d, 32'h1234_5678);

			axil_write(REG_DST_ADDR, 32'h8765_4320);
			axil_read(REG_DST_ADDR, d);
			expect_eq("DST_ADDR", d, 32'h8765_4320);

			axil_write(REG_CTRL, 32'hFFFF_FFC0);
			axil_read(REG_CTRL, d);
			expect_eq("CTRL truncation", d, 32'h0000_0000);

			axil_write(REG_LEN, 32'hFFFF_FFFF); // LEN_W = 7
			axil_read(REG_LEN, d);
			expect_eq("LEN truncation", d, 32'h0000_007F);

			axil_write(REG_NJOBS, 32'hFFFF_FFFF); // NJOBS_W = 16
			axil_read(REG_NJOBS, d);
			expect_eq("NJOBS truncation", d, 32'h0000_FFFF);
		end
	endtask

	task automatic test_tile0_csr_pop;
		int w;
		logic [31:0] beat;
		begin
			phase = "tile0_csr_pop";
			launch_fill(WEIGHTS_JOB, 1, SRC_BASE);
			wait_level(MATRIX_SIZE, 500);
			wait_bit(ST_DMA_BUSY, 1'b0, "read dma to retire", 500);
			for (w = 0; w < TILE_BEATS; w++) begin
				axil_read(REG_RESULT, beat);
				checks++;
				if (beat !== gold[w])
					fail($sformatf("csr pop word %0d = %08h, expected %08h", w, beat, gold[w]));
			end
		end
	endtask

	task automatic test_tile0_store;
		begin
			phase = "tile0_store";
			clear_region(DST_BASE, TILE_BEATS);
			launch_fill(WEIGHTS_JOB, 1, SRC_BASE);
			wait_level(MATRIX_SIZE, 500);
			wait_bit(ST_DMA_BUSY, 1'b0, "read dma to retire", 500);
			axil_write(REG_DST_ADDR, DST_BASE);
			axil_write(REG_CTRL, ctrl_bits(1, 0, 0, 1, 0, 0));
			axil_write(REG_CTRL, ctrl_bits(1, 0, 0, 0, 0, 0));
			wait_bit(ST_WDMA_DONE, 1'b1, "write dma to finish", 500);
			check_tile("store", 0, DST_BASE);
		end
	endtask

	task automatic test_bad_descriptor;
		logic [31:0] s;
		int w;
		logic [31:0] beat;
		begin
			phase = "bad_descriptor";
			launch_fill(0, 1, SRC_BASE);
			repeat (20) @(posedge clk);
			axil_read(REG_STATUS, s);
			checks++;
			if (!s[ST_DMA_ERR])
				fail($sformatf("zero-length job did not flag DMA_ERR: %08h", s));

			launch_fill(WEIGHTS_JOB, 1, SRC_BASE);
			wait_level(MATRIX_SIZE, 500);
			wait_bit(ST_DMA_BUSY, 1'b0, "read dma to retire after recovery", 500);
			for (w = 0; w < TILE_BEATS; w++) begin
				axil_read(REG_RESULT, beat);
				checks++;
				if (beat !== gold[w])
					fail($sformatf("recovery word %0d = %08h, expected %08h", w, beat, gold[w]));
			end
		end
	endtask

	task automatic test_chained_stream;
		int t, t0, cyc;
		begin
			phase = "chained_stream";
			clear_region(ALT_DST, TILES * TILE_BEATS);

			axil_write(REG_CTRL, ctrl_bits(1, 0, 0, 0, 0, 0));
			axil_write(REG_DST_ADDR, ALT_DST);
			axil_write(REG_SRC_ADDR, SRC_BASE);
			axil_write(REG_LEN, 32'(WEIGHTS_JOB));
			axil_write(REG_NJOBS, 32'(TILES - 1));
			axil_write(REG_CTRL, ctrl_bits(1, 0, 1, 0, 1, 0));
			t0 = int'($time / (2 * CLK_HALF));
			axil_write(REG_CTRL, ctrl_bits(1, 1, 1, 0, 1, 0));

			wait_bit(ST_W_VALID, 1'b1, "weights to land", 500);
			wait_bit(ST_CTRL_BUSY, 1'b0, "weights job to retire", 500);
			axil_write(REG_SRC_ADDR, SRC_BASE + 32'(4 * WEIGHTS_JOB));
			axil_write(REG_LEN, 32'(TILE_WORDS));
			axil_write(REG_CTRL, ctrl_bits(1, 0, 0, 0, 1, 1));

			wait_tiles(TILES, (400 * TILES) + 2000);
			cyc = int'($time / (2 * CLK_HALF)) - t0;

			for (t = 0; t < TILES; t++) check_tile("chained", t, ALT_DST);

			checks++;
			if (stored_bursts < TILES)
				fail($sformatf("write slave saw %0d bursts, expected %0d", stored_bursts, TILES));
			$display("[%0t] %0d chained tiles in %0d cycles (%0.1f cyc/tile)", $time, TILES, cyc, real'(cyc) / real'(TILES));
		end
	endtask

	initial begin
		#WATCHDOG;
		$display("[%0t] FATAL: watchdog expired in phase '%s'", $time, phase);
		$fatal(1, "tb_top: watchdog");
	end

	initial begin
		$dumpfile("tb_top.vcd");
		$dumpvars(0, tb_top);

		errors = 0;
		checks = 0;
		phase = "init";
		init();
		load_vectors();
		dut_rst();

		check_geometry();
		test_csr_reset();
		test_csr_readback();

		dut_rst();
		test_tile0_csr_pop();

		dut_rst();
		test_tile0_store();

		dut_rst();
		test_bad_descriptor();

		dut_rst();
		test_chained_stream();

		repeat (10) @(posedge clk);
		
		if (errors == 0) begin
			$display("tb_top: PASS (%0d checks)", checks);
			$finish;
		end else begin
			$display("tb_top: FAIL (%0d errors in %0d checks)", errors, checks);
			$fatal(1, "tb_top failed");
		end
	end

endmodule
