from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
RTL = ROOT / "rtl"
VECTORS = ROOT / "tb" / "vectors"

MACRO_MODELS = ROOT / "sram22_64x32m4w8"

SRC_BASE = 0x1000
DST_BASE = 0x2000
ALT_DST = 0x8000

CTRL_BITS = ("EN", "GO", "LOAD_W", "STORE", "AUTO_ST", "AUTO_FILL")
STATUS_BITS = ("DMA_BUSY", "DMA_DONE", "DMA_ERR", "FILL_DONE", "CTRL_BUSY", "ARRAY_BUSY", "ARRAY_DONE", "PP_SEL", "W_VALID", "RES_VALID", "RES_OVF", "WDMA_BUSY", "WDMA_DONE", "WDMA_ERR", "AF_BUSY", "LEVEL_LSB", "TILE_LSB")
REGS = ("CTRL", "STATUS", "SRC_ADDR", "LEN", "RESULT", "DST_ADDR", "NJOBS")


def clk_period_ns(default=10.0):
    try:
        return float(json.loads((ROOT / "config.json").read_text())["CLOCK_PERIOD"])
    except (OSError, ValueError, KeyError):
        return default


def rtl_sources():
    macros = [MACRO_MODELS / bb.name if (MACRO_MODELS / bb.name).is_file() else bb
              for bb in sorted(RTL.glob("*.v"))]
    return sorted(RTL.glob("*.sv")) + macros

@dataclass(frozen=True)
class Geometry:
    n: int
    data_w: int
    result_w: int
    level_bits: int = 0
    tile_bits: int = 0
    reg: dict = field(default_factory=dict)
    ctrl: dict = field(default_factory=dict)
    st: dict = field(default_factory=dict)

    @property
    def tile_words(self):
        return self.n

    @property
    def weights_job(self):
        return 2 * self.n

    @property
    def elems(self):
        return self.n * self.n

    @property
    def res_bits(self):
        return self.elems * self.result_w

    @property
    def tile_beats(self):
        assert self.res_bits % 32 == 0, "tile must be a whole number of beats"
        return self.res_bits // 32

    @property
    def tile_bytes(self):
        return self.tile_beats * 4

    @classmethod
    def from_dut(cls, dut):
        val = lambda h, name: int(getattr(h, name).value)
        lsb = val(dut.u_csr, "ADDR_LSB")
        return cls(
            n=val(dut, "MATRIX_SIZE"), data_w=val(dut, "DATA_WIDTH"), result_w=val(dut, "RESULT_W"), 
            level_bits=len(dut.fifo_level), tile_bits=len(dut.tile_cnt_r),
            reg={k: val(dut.u_csr, f"IDX_{k}") << lsb for k in REGS}, ctrl={k: val(dut, f"CTRL_{k}") for k in CTRL_BITS}, 
            st={k: val(dut, f"ST_{k}") for k in STATUS_BITS},
        )
    
    @classmethod
    def from_source(cls):
        p = _source_localparams(RTL / "top.sv")
        return cls(n=p["MATRIX_SIZE"], data_w=p["DATA_WIDTH"], result_w=p["RESULT_W"])

    def pack(self, m):
        mask = (1 << self.data_w) - 1
        return [sum((int(v) & mask) << (self.data_w * c) for c, v in enumerate(row))
                for row in np.asarray(m)]

    def sext(self, word, bits=None):
        bits = bits or self.result_w
        word &= (1 << bits) - 1
        return word - (1 << bits) if word >> (bits - 1) else word

    def rand(self, rng):
        lim = 1 << (self.data_w - 1)
        return rng.integers(-lim, lim, (self.n, self.n)).astype(np.int64)

    def extreme(self):
        return np.full((self.n, self.n), -(1 << (self.data_w - 1)), np.int64)

    def golden(self, a, b):
        return np.asarray(a, np.int64) @ np.asarray(b, np.int64)

    def pack_results(self, m):
        mask = (1 << self.result_w) - 1
        stream = 0
        for j, v in enumerate(np.asarray(m, np.int64).ravel()):
            stream |= (int(v) & mask) << (self.result_w * j)
        return [(stream >> (32 * i)) & 0xffffffff for i in range(self.tile_beats)]

    def unpack_results(self, words):
        stream = 0
        for i, w in enumerate(words):
            stream |= (int(w) & 0xffffffff) << (32 * i)
        mask = (1 << self.result_w) - 1
        return [self.sext((stream >> (self.result_w * j)) & mask, self.result_w)
                for j in range(self.elems)]

    def stream(self, rng, tiles):
        b = self.rand(rng)
        a = [self.rand(rng) for _ in range(tiles)]
        return b, a, self.pack(b) + [w for t in a for w in self.pack(t)]

_LOCALPARAM = re.compile(r"localparam\s+integer\s+(\w+)\s*=\s*([^;]+);")

def _source_localparams(path):
    env = {"clog2": lambda x: max(1, (int(x) - 1).bit_length())}
    out = {}
    for name, expr in _LOCALPARAM.findall(path.read_text()):
        try:
            out[name] = int(eval(expr.replace("$clog2", "clog2"), {"__builtins__": {}}, {**env, **out}))
        except Exception:
            continue
    return out

TB_TILES = 8  # tiles in the chained stream tb/tb_top.sv runs

def write_vectors(seed=7, tiles=TB_TILES):
    g = Geometry.from_source()
    p = _source_localparams(RTL / "top.sv")
    b, a, words = g.stream(np.random.default_rng(seed), tiles)
    gold = [w for tile in a for w in g.pack_results(g.golden(tile, b))]

    VECTORS.mkdir(parents=True, exist_ok=True)
    (VECTORS / "stim.hex").write_text("".join(f"{w:08x}\n" for w in words))
    (VECTORS / "golden.hex").write_text("".join(f"{w:08x}\n" for w in gold))

    params = {
        "MATRIX_SIZE": g.n,
        "DATA_WIDTH": g.data_w,
        "RESULT_W": g.result_w,
        "TILE_BEATS": g.tile_beats,
        "TILE_BYTES": g.tile_bytes,
        "TILE_WORDS": g.tile_words,     # words of A per tile
        "WEIGHTS_JOB": g.weights_job,   # words of the B+A0 job
        "LEVEL_W": p["LEVEL_W"],
        "ST_TILE_LSB": p["ST_TILE_LSB"],
        "TILES": tiles,
        "STIM_WORDS": len(words),
        "GOLD_WORDS": len(gold),
    }
    body = "".join(f"`define TB_{k} {v}\n" for k, v in params.items())
    (VECTORS / "tb_params.vh").write_text(
        "// generated by tb/test_top.py --gen -- do not edit\n"
        "`ifndef TB_PARAMS_VH\n`define TB_PARAMS_VH\n" + body + "`endif\n")

    print(f"wrote {VECTORS}/stim.hex ({len(words)} words), "
          f"golden.hex ({len(gold)} words = {tiles} x {g.tile_beats}) and "
          f"tb_params.vh for {g.n}x{g.n} x {g.data_w}b")


if __name__ == "__main__" and "--gen" in sys.argv:
    write_vectors()
    sys.exit(0)


import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge
from cocotb.utils import get_sim_time

CLK_NS = clk_period_ns()


class Accel:
    def __init__(self, dut, g):
        self.dut, self.g = dut, g
        self.mem = {}    # byte addr -> word, serves the read DMA
        self.wmem = {}   # byte addr -> word, captures the write DMA

    @classmethod
    async def new(cls, dut):
        self = cls(dut, Geometry.from_dut(dut))
        for handle in dut:                      # every top-level input is i_*
            if handle._name.startswith("i_"):
                handle.value = 0
        cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
        await self.reset()
        cocotb.start_soon(self._read_slave())
        cocotb.start_soon(self._write_slave())
        cocotb.start_soon(self._swap_monitor())
        return self

    def ctrl(self, *names):
        return sum(1 << self.g.ctrl[n] for n in names)

    def _bit(self, status, name):
        return (status >> self.g.st[name]) & 1

    def _field(self, status, lsb_name, bits):
        return (status >> self.g.st[lsb_name]) & ((1 << bits) - 1)

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
        words = [self.wmem[addr + 4 * i] for i in range(self.g.tile_beats)]
        return np.array(self.g.unpack_results(words), np.int64).reshape(self.g.n, self.g.n)

    async def wr(self, reg, data):
        d = self.dut
        await RisingEdge(d.clk)
        d.i_s_axil_awaddr.value = self.g.reg[reg]
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

    async def rd(self, reg):
        d = self.dut
        await RisingEdge(d.clk)
        d.i_s_axil_araddr.value = self.g.reg[reg]
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

    # AXI4 mem
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
            addr = int(d.o_m_axi_awaddr.value)
            beats = self.g.tile_beats  # awlen is a wrapper tie, not a dut pin
            d.i_m_axi_awready.value = 1
            await RisingEdge(d.clk)
            d.i_m_axi_awready.value = 0
            d.i_m_axi_wready.value = 1
            n = 0
            while n < beats:
                await ReadOnly()
                fired = bool(d.o_m_axi_wvalid.value)
                data = int(d.o_m_axi_wdata.value) if fired else 0
                last = bool(d.o_m_axi_wlast.value) if fired else False
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

    async def status(self):
        return await self.rd("STATUS")

    async def check(self):
        s = await self.status()
        assert not self._bit(s, "DMA_ERR"), f"read dma error, STATUS=0x{s:08x}"
        assert not self._bit(s, "WDMA_ERR"), f"write dma error, STATUS=0x{s:08x}"
        assert not self._bit(s, "RES_OVF"), f"result fifo overflow, STATUS=0x{s:08x}"
        return s

    async def _poll(self, done, what, tries):
        for _ in range(tries):
            if done(await self.check()):
                return
            await RisingEdge(self.dut.clk)
        raise TimeoutError(f"timed out waiting for {what}")

    async def wait_idle(self):
        await self._poll(lambda s: not self._bit(s, "DMA_BUSY"), "read dma to go idle", 500)

    async def wait_level(self, count):
        await self._poll(
            lambda s: self._field(s, "LEVEL_LSB", self.g.level_bits) >= count,
            f"{count} results in the fifo", 500)

    async def wait_wdma(self):
        await self._poll(lambda s: self._bit(s, "WDMA_DONE"), "write dma to finish", 500)

    async def wait_tiles(self, n):
        mask = (1 << self.g.tile_bits) - 1
        seen = prev = 0
        for _ in range(400 * n + 2000):
            cnt = self._field(await self.check(), "TILE_LSB", self.g.tile_bits)
            seen += (cnt - prev) & mask
            prev = cnt
            if seen >= n:
                return
            await RisingEdge(self.dut.clk)
        raise TimeoutError(f"only {seen}/{n} tiles stored")

    async def job(self, words, load_w, src=SRC_BASE, extra=()):
        base = self.ctrl("EN", *(("LOAD_W",) if load_w else ()), *extra)
        await self.wr("SRC_ADDR", src)
        await self.wr("LEN", words)
        await self.wr("CTRL", base)
        await self.wr("CTRL", base | self.ctrl("GO"))

    async def pop_tile(self):
        words = [await self.rd("RESULT") for _ in range(self.g.tile_beats)]
        return np.array(self.g.unpack_results(words),
                        np.int64).reshape(self.g.n, self.g.n)

    async def run_chained(self, dst, tiles, batch=1):
        g = self.g
        rest = tiles - 1                    # the weights job carries tile 0
        assert rest % batch == 0, f"{rest} tiles after the first is not a multiple of {batch}"
        await self.wr("CTRL", self.ctrl("EN"))
        await self.wr("DST_ADDR", dst)
        await self.wr("SRC_ADDR", SRC_BASE)
        await self.wr("LEN", g.weights_job)
        await self.wr("NJOBS", rest // batch)
        await self.wr("CTRL", self.ctrl("EN", "LOAD_W", "AUTO_ST"))
        t0 = self.cycles()
        await self.wr("CTRL", self.ctrl("EN", "LOAD_W", "AUTO_ST", "GO"))

        await self._poll(
            lambda s: self._bit(s, "W_VALID") and not self._bit(s, "CTRL_BUSY"),
            "weights job to retire", 500)
        await self.wr("SRC_ADDR", SRC_BASE + g.weights_job * 4)
        await self.wr("LEN", batch * g.tile_words)
        await self.wr("CTRL", self.ctrl("EN", "AUTO_ST", "AUTO_FILL"))
        await self.wait_tiles(tiles)
        return self.cycles() - t0

    async def run_cpu(self, b, a, dst):
        g = self.g
        for i, tile in enumerate(a):
            await self.wait_idle()
            self.mem.clear()
            self.load(SRC_BASE, g.pack(b) + g.pack(tile) if i == 0 else g.pack(tile))
            await self.job(words=g.weights_job if i == 0 else g.tile_words, load_w=(i == 0))
            await self.wait_level(g.n)   # one tile == n result rows
            await self.wr("DST_ADDR", dst + i * g.tile_bytes)
            await self.wr("CTRL", self.ctrl("EN", "STORE"))
            await self.wr("CTRL", self.ctrl("EN"))
            await self.wait_wdma()


def check_tiles(acc, a, b, dst, label):
    for i, tile in enumerate(a):
        got, exp = acc.tile_at(dst + i * acc.g.tile_bytes), acc.g.golden(tile, b)
        assert (got == exp).all(), f"{label} tile {i}\ngot\n{got}\nexp\n{exp}"



@cocotb.test()
async def test_matmul(dut):
    acc = await Accel.new(dut)
    g = acc.g
    b, a, _ = g.stream(np.random.default_rng(1), tiles=2)

    acc.load(SRC_BASE, g.pack(b) + g.pack(a[0]))
    await acc.job(words=g.weights_job, load_w=True)
    await acc.wait_idle()
    got, exp = await acc.pop_tile(), g.golden(a[0], b)
    assert (got == exp).all(), f"load_w tile\ngot\n{got}\nexp\n{exp}"

    acc.mem.clear()
    acc.load(SRC_BASE, g.pack(a[1]))
    await acc.job(words=g.tile_words, load_w=False)
    await acc.wait_idle()
    got, exp = await acc.pop_tile(), g.golden(a[1], b)
    assert (got == exp).all(), f"reuse tile\ngot\n{got}\nexp\n{exp}"


@cocotb.test()
async def test_extremes(dut):
    acc = await Accel.new(dut)
    g = acc.g
    b = a = g.extreme()
    acc.load(SRC_BASE, g.pack(b) + g.pack(a))
    await acc.job(words=g.weights_job, load_w=True)
    await acc.wait_idle()
    exp = g.golden(a, b)
    assert exp.max() < (1 << (g.result_w - 1)), "result width too narrow for extremes"
    assert exp.max() >= (1 << (g.result_w - 2)), "extremes no longer exercise the top bit"

    got = await acc.pop_tile()
    assert (got == exp).all(), f"extremes\ngot\n{got}\nexp\n{exp}"


@cocotb.test()
async def test_bad_descriptor(dut):
    acc = await Accel.new(dut)
    g = acc.g

    await acc.job(words=0, load_w=True)
    await ClockCycles(dut.clk, 20)
    s = await acc.status()
    assert acc._bit(s, "DMA_ERR"), f"zero-length job did not flag DMA_ERR: 0x{s:08x}"

    b, a, _ = g.stream(np.random.default_rng(11), tiles=1)
    acc.load(SRC_BASE, g.pack(b) + g.pack(a[0]))
    await acc.job(words=g.weights_job, load_w=True)
    await acc.wait_idle()
    got, exp = await acc.pop_tile(), g.golden(a[0], b)
    assert (got == exp).all(), f"recovery tile\ngot\n{got}\nexp\n{exp}"


@cocotb.test()
async def test_stream(dut):
    acc = await Accel.new(dut)
    g = acc.g
    tiles = 40
    b, a, words = g.stream(np.random.default_rng(2), tiles)
    acc.load(SRC_BASE, words)

    cyc = await acc.run_chained(DST_BASE, tiles)
    check_tiles(acc, a, b, DST_BASE, "chained")
    dut._log.info(f"{tiles} chained tiles: {cyc:.0f} cycles, {cyc / tiles:.1f}/tile")


@cocotb.test()
async def test_batched_fill(dut):
    acc = await Accel.new(dut)
    g = acc.g
    tiles = 7
    b, a, words = g.stream(np.random.default_rng(5), tiles)
    acc.load(SRC_BASE, words)

    await acc.wr("CTRL", acc.ctrl("EN"))
    await acc.wr("DST_ADDR", DST_BASE)
    await acc.wr("SRC_ADDR", SRC_BASE)
    await acc.wr("LEN", len(words))
    await acc.wr("CTRL", acc.ctrl("EN", "AUTO_ST"))
    t0 = acc.cycles()
    await acc.wr("CTRL", acc.ctrl("EN", "AUTO_ST", "GO"))
    await acc.wait_tiles(tiles)
    cyc = acc.cycles() - t0

    check_tiles(acc, a, b, DST_BASE, "batched")
    dut._log.info(f"{tiles} tiles from one {len(words)}-word fill: " f"{cyc:.0f} cycles, {cyc / tiles:.1f}/tile")


@cocotb.test()
async def test_speedup(dut):
    acc = await Accel.new(dut)
    g = acc.g
    tiles = 8
    b, a, words = g.stream(np.random.default_rng(3), tiles)

    t0 = acc.cycles()
    await acc.run_cpu(b, a, DST_BASE)
    cpu = (acc.cycles() - t0) / tiles

    await acc.reset()
    acc.mem.clear()
    acc.wmem.clear()
    acc.load(SRC_BASE, words)
    chained = await acc.run_chained(ALT_DST, tiles) / tiles
    check_tiles(acc, a, b, ALT_DST, "speedup")

    dut._log.info(f"cpu-sequenced {cpu:.1f} cyc/tile, chained {chained:.1f} cyc/tile, " f"{cpu / chained:.2f}x")
    assert chained < cpu / 2, f"chain regressed: {cpu:.1f} -> {chained:.1f} cyc/tile"


if __name__ == "__main__":
    from cocotb_tools.runner import get_runner

    sources = rtl_sources()
    if not sources:
        sys.exit(f"no rtl sources under {RTL}")
    runner = get_runner("icarus")
    kw = dict(hdl_toplevel="top", build_dir=ROOT / "build" / "cocotb", timescale=("1ps", "1ps"), waves=True)
    runner.build(sources=sources, build_args=["-g2012"], always=True, **kw)
    runner.test(test_module="test_top", test_dir=ROOT / "tb", **kw)
