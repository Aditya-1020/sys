import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
VECTORS = ROOT / "tb" / "vectors"

N = 4
RESULT_BITS = 18
CLK_NS = 10
SRC_BASE = 0x1000
DST_BASE = 0x2000

CTRL = 0x00
STATUS = 0x04
SRC = 0x08
LEN = 0x0C
RESULT = 0x10
DST = 0x14
NJOBS = 0x18

EN = 0x00000001
GO = 0x00000002
LOAD_W = 0x00000004
STORE = 0x00000008
AUTO_ST = 0x00000010
AUTO_FILL = 0x00000020

# Status bits
DMA_BUSY = 0x00000001
DMA_ERR = 0x00000004
RES_OVF = 0x00000400
WDMA_DONE = 0x00001000
WDMA_ERR = 0x00002000

TILE_LSB = 22

def pack(m):
	return np.ascontiguousarray(m, np.int8).view(np.uint32).ravel().tolist()


def sign_extend(word):
	word &= (1 << RESULT_BITS) - 1
	return word - (1 << RESULT_BITS) if word >> (RESULT_BITS - 1) else word


def golden(a, b):
	return a.astype(np.int32) @ b.astype(np.int32)


def stream(rng, tiles):
	b = rng.integers(-128, 128, (N, N), dtype=np.int8)
	a = [rng.integers(-128, 128, (N, N), dtype=np.int8) for _ in range(tiles)]
	words = pack(b) + [w for t in a for w in pack(t)]
	return b, a, words


class Accel:
	def __init__(self, dut):
		self.dut = dut
		# byte addr -> word
		self.mem = {}   # serves the read DMA
		self.wmem = {}  #captures the write DMA

	@classmethod
	async def new(cls, dut): # new clock reset full
		self = cls(dut)
		for sig in ("i_s_axil_awaddr", "i_s_axil_awvalid", "i_s_axil_wdata", "i_s_axil_wstrb",
					"i_s_axil_wvalid", "i_s_axil_bready", "i_s_axil_araddr", "i_s_axil_arvalid",
					"i_s_axil_rready", "i_m_axi_arready", "i_m_axi_rdata", "i_m_axi_rresp",
					"i_m_axi_rlast", "i_m_axi_rvalid", "i_m_axi_awready", "i_m_axi_wready",
					"i_m_axi_bresp", "i_m_axi_bvalid"):
			getattr(dut, sig).value = 0
		cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
		await self.reset()
		cocotb.start_soon(self._read_slave())
		cocotb.start_soon(self._write_slave())
		cocotb.start_soon(self._swap_monitor())
		return self

	# pp_buf_sram swap contract: i_swap must miss the array read and its shadow
	async def _swap_monitor(self):
		buf = self.dut.u_sram
		prev_cs = 0
		while True:
			await RisingEdge(self.dut.clk)
			await ReadOnly()
			swap, cs = int(buf.i_swap.value), int(buf.i_cs_array.value)
			assert not (swap and (cs or prev_cs)), "i_swap collided with an array read"
			prev_cs = cs

	async def reset(self):
		self.dut.rstn.value = 0
		await ClockCycles(self.dut.clk, 8)
		self.dut.rstn.value = 1
		await ClockCycles(self.dut.clk, 8)

	def cycles(self):
		return get_sim_time("ns") / CLK_NS

	def load(self, addr, words):
		for i, w in enumerate(words):
			self.mem[addr + 4 * i] = w

	def tile_at(self, addr):
		vals = [sign_extend(self.wmem[addr + 4 * i]) for i in range(N * N)]
		return np.array(vals, np.int32).reshape(N, N)

	# axil master
	async def wr(self, addr, data):
		d = self.dut
		await RisingEdge(d.clk)
		d.i_s_axil_awaddr.value = addr
		d.i_s_axil_awvalid.value = 1
		d.i_s_axil_wdata.value = data
		d.i_s_axil_wstrb.value = 0xF
		d.i_s_axil_wvalid.value = 1
		d.i_s_axil_bready.value = 1
		aw = w = False
		while not (aw and w):
			await RisingEdge(d.clk)
			if not aw and d.o_s_axil_awready.value:
				d.i_s_axil_awvalid.value = 0
				aw = True
			if not w and d.o_s_axil_wready.value:
				d.i_s_axil_wvalid.value = 0
				w = True
		while not d.o_s_axil_bvalid.value:
			await RisingEdge(d.clk)
		await RisingEdge(d.clk)
		d.i_s_axil_bready.value = 0

	async def rd(self, addr):
		d = self.dut
		await RisingEdge(d.clk)
		d.i_s_axil_araddr.value = addr
		d.i_s_axil_arvalid.value = 1
		d.i_s_axil_rready.value = 1
		while True:
			await RisingEdge(d.clk)
			if d.o_s_axil_arready.value:
				d.i_s_axil_arvalid.value = 0
				break
		while not d.o_s_axil_rvalid.value:
			await RisingEdge(d.clk)
		data = int(d.o_s_axil_rdata.value)
		await RisingEdge(d.clk)
		d.i_s_axil_rready.value = 0
		return data

	# axi4 mem
	async def _read_slave(self):
		d = self.dut
		while True:
			while not d.o_m_axi_arvalid.value:
				await RisingEdge(d.clk)
			beats = int(d.o_m_axi_arlen.value) + 1
			addr = int(d.o_m_axi_araddr.value)
			d.i_m_axi_arready.value = 1
			await RisingEdge(d.clk)
			d.i_m_axi_arready.value = 0
			for i in range(beats):
				d.i_m_axi_rdata.value = self.mem.get(addr + 4 * i, 0)
				d.i_m_axi_rvalid.value = 1
				d.i_m_axi_rlast.value = int(i == beats - 1)
				await RisingEdge(d.clk)
				while not d.o_m_axi_rready.value:
					await RisingEdge(d.clk)
			d.i_m_axi_rvalid.value = d.i_m_axi_rlast.value = 0

	async def _write_slave(self):
		d = self.dut
		while True:
			while not d.o_m_axi_awvalid.value:
				await RisingEdge(d.clk)
			addr= int(d.o_m_axi_awaddr.value)
			beats = int(d.o_m_axi_awlen.value) + 1
			d.i_m_axi_awready.value = 1
			await RisingEdge(d.clk)
			d.i_m_axi_awready.value = 0
			d.i_m_axi_wready.value = 1
			n = 0
			while n < beats:
				await ReadOnly()
				fired = bool(d.o_m_axi_wvalid.value)
				data = int(d.o_m_axi_wdata.value)
				last = bool(d.o_m_axi_wlast.value)
				await RisingEdge(d.clk)
				if fired:
					self.wmem[addr + 4 * n] = data
					n += 1
					assert last == (n == beats), f"wlast at beat {n} of {beats}"
			d.i_m_axi_wready.value = 0
			d.i_m_axi_bvalid.value = 1
			while True:
				await ReadOnly()
				done = bool(d.o_m_axi_bready.value)
				await RisingEdge(d.clk)
				if done:
					break
			d.i_m_axi_bvalid.value = 0

	async def check_status(self):
		s = await self.rd(STATUS)
		assert not s & DMA_ERR, f"read dma error, STATUS=0x{s:08x}"
		assert not s & WDMA_ERR, f"write dma error, STATUS=0x{s:08x}"
		assert not s & RES_OVF, f"result fifo overflow, STATUS=0x{s:08x}"
		return s

	async def wait_idle(self, timeout=500):
		for _ in range(timeout):
			if not await self.check_status() & DMA_BUSY:
				return
			await RisingEdge(self.dut.clk)
		raise TimeoutError("read dma never went idle")

	async def wait_tiles(self, n, timeout=20000):
		seen = prev = 0
		for _ in range(timeout):
			cnt = (await self.check_status() >> TILE_LSB) & 0xF
			seen += (cnt - prev) & 0xF
			prev = cnt
			if seen >= n:
				return
			await RisingEdge(self.dut.clk)
		raise TimeoutError(f"only {seen}/{n} tiles stored")

	async def job(self, words, load_w, src=SRC_BASE, extra=0):
		ctrl = EN | (LOAD_W if load_w else 0) | extra
		await self.wr(SRC, src)
		await self.wr(LEN, words)
		await self.wr(CTRL, ctrl)
		await self.wr(CTRL, ctrl | GO)

	async def pop_tile(self):
		vals = [sign_extend(await self.rd(RESULT)) for _ in range(N * N)]
		return np.array(vals, np.int32).reshape(N, N)

	async def run_chained(self, dst, tiles):
		await self.wr(CTRL, EN)
		await self.wr(DST, dst)
		await self.wr(SRC, SRC_BASE)
		await self.wr(LEN, 2 * N)
		await self.wr(NJOBS, tiles - 1)
		await self.wr(CTRL, EN | LOAD_W | AUTO_ST)
		t0 = self.cycles()
		await self.wr(CTRL, EN | LOAD_W | AUTO_ST | GO)
		await self.wr(SRC, SRC_BASE + 2 * N * 4)
		await self.wr(LEN, N)
		await self.wr(CTRL, EN | AUTO_ST | AUTO_FILL)
		await self.wait_tiles(tiles)
		return self.cycles() - t0

	async def run_cpu(self, b, a, dst): # seq fill and stores
		for i, tile in enumerate(a):
			await self.wait_idle()
			self.mem.clear()
			self.load(SRC_BASE, pack(b) + pack(tile) if i == 0 else pack(tile))
			await self.job(words=2 * N if i == 0 else N, load_w=(i == 0))
			for _ in range(500):
				if ((await self.check_status()) >> 16 & 0x3F) >= N * N:
					break
				await RisingEdge(self.dut.clk)
			await self.wr(DST, dst + i * N * N * 4)
			await self.wr(CTRL, EN | STORE)
			await self.wr(CTRL, EN)
			for _ in range(500):
				if await self.check_status() & WDMA_DONE:
					break
				await RisingEdge(self.dut.clk)


def write_vectors(seed=7):
	rng = np.random.default_rng(seed)
	b, a, words = stream(rng, tiles=1)
	VECTORS.mkdir(parents=True, exist_ok=True)
	(VECTORS / "stim.hex").write_text("".join(f"{w:08x}\n" for w in words))
	(VECTORS / "golden.hex").write_text("".join(f"{int(v) & 0xffffffff:08x}\n" for v in golden(a[0], b).ravel()))
	print(f"wrote {VECTORS}/stim.hex ({len(words)} words) and golden.hex ({N*N} words)")


if __name__ == "__main__" and "--gen" in sys.argv:
	write_vectors()
	sys.exit(0)

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge
from cocotb.utils import get_sim_time


@cocotb.test()
async def test_matmul(dut):
	rng = np.random.default_rng(1)
	acc = await Accel.new(dut)
	b, a, _ = stream(rng, tiles=2)

	acc.load(SRC_BASE, pack(b) + pack(a[0]))
	await acc.job(words=2 * N, load_w=True)
	await acc.wait_idle()
	got = await acc.pop_tile()
	assert (got == golden(a[0], b)).all(), f"load_w tile\ngot\n{got}\nexp\n{golden(a[0], b)}"

	acc.mem.clear()
	acc.load(SRC_BASE, pack(a[1]))
	await acc.job(words=N, load_w=False)
	await acc.wait_idle()
	got = await acc.pop_tile()
	assert (got == golden(a[1], b)).all(), f"reuse tile\ngot\n{got}\nexp\n{golden(a[1], b)}"


@cocotb.test()
async def test_extremes(dut):
	acc = await Accel.new(dut)
	b = np.full((N, N), -128, np.int8)
	a = np.full((N, N), -128, np.int8)
	acc.load(SRC_BASE, pack(b) + pack(a))
	await acc.job(words=2 * N, load_w=True)
	await acc.wait_idle()
	got = await acc.pop_tile()
	assert (got == golden(a, b)).all(), f"extremes\ngot\n{got}\nexp\n{golden(a, b)}"


@cocotb.test()
async def test_stream(dut):
	rng = np.random.default_rng(2)
	acc = await Accel.new(dut)
	tiles = 40
	b, a, words = stream(rng, tiles)
	acc.load(SRC_BASE, words)

	cyc = await acc.run_chained(DST_BASE, tiles)
	for i, tile in enumerate(a):
		got = acc.tile_at(DST_BASE + i * N * N * 4)
		assert (got == golden(tile, b)).all(), f"tile {i}\ngot\n{got}\nexp\n{golden(tile, b)}"
	dut._log.info(f"{tiles} chained tiles: {cyc:.0f} cycles, {cyc/tiles:.1f}/tile")


@cocotb.test()
async def test_batched_fill(dut):
	rng = np.random.default_rng(5)
	acc = await Accel.new(dut)
	tiles = 7
	b, a, words = stream(rng, tiles)
	acc.load(SRC_BASE, words)

	await acc.wr(CTRL, EN)
	await acc.wr(DST, DST_BASE)
	await acc.wr(SRC, SRC_BASE)
	await acc.wr(LEN, len(words))
	await acc.wr(CTRL, EN | AUTO_ST)
	t0 = acc.cycles()
	await acc.wr(CTRL, EN | AUTO_ST | GO)
	await acc.wait_tiles(tiles)
	cyc = acc.cycles() - t0

	for i, tile in enumerate(a):
		got = acc.tile_at(DST_BASE + i * N * N * 4)
		assert (got == golden(tile, b)).all(), f"tile {i}\ngot\n{got}\nexp\n{golden(tile, b)}"
	dut._log.info(f"{tiles} tiles from one {len(words)}-word fill: {cyc:.0f} cycles, {cyc/tiles:.1f}/tile")


@cocotb.test()
async def test_speedup(dut):
	rng = np.random.default_rng(3)
	acc = await Accel.new(dut)
	tiles = 8
	b, a, words = stream(rng, tiles)

	cpu = acc.cycles()
	await acc.run_cpu(b, a, DST_BASE)
	cpu = (acc.cycles() - cpu) / tiles

	await acc.reset()
	acc.mem.clear()
	acc.wmem.clear()
	acc.load(SRC_BASE, words)
	chained = await acc.run_chained(0x8000, tiles) / tiles
	for i, tile in enumerate(a):
		got = acc.tile_at(0x8000 + i * N * N * 4)
		assert (got == golden(tile, b)).all(), f"tile {i}\ngot\n{got}\nexp\n{golden(tile, b)}"

	dut._log.info(f"cpu-sequenced {cpu:.1f} cyc/tile, chained {chained:.1f} cyc/tile, " f"{cpu/chained:.2f}x")
	assert chained < cpu / 2, f"chain regressed: {cpu:.1f} -> {chained:.1f} cyc/tile"


if __name__ == "__main__":
	from cocotb_tools.runner import get_runner

	sources = sorted((ROOT / "rtl").glob("*.sv")) + sorted((ROOT / "rtl").glob("*.v"))
	if not sources:
		sys.exit(f"no rtl sources under {ROOT / 'rtl'}")
	runner = get_runner("icarus")
	kw = dict(hdl_toplevel="top", build_dir=ROOT / "build" / "cocotb",
			  timescale=("1ps", "1ps"), waves=True)
	runner.build(sources=sources, build_args=["-g2012"], always=True, **kw)
	runner.test(test_module="test_top", test_dir=ROOT / "tb", **kw)
