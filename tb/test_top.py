from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RTL = ROOT / "rtl"
VECTORS = ROOT / "tb" / "vectors"
MACRO = ROOT / "sram22_64x32m4w8"


def rtl_sources():
    sv = sorted(RTL.glob("*.sv"))
    pkgs = [p for p in sv if p.name.startswith("pkg_")]
    rest = [p for p in sv if p not in pkgs]
    macros = [MACRO / b.name if (MACRO / b.name).is_file() else b for b in sorted(RTL.glob("*.v"))]
    return pkgs + rest + macros


def load_meta():
    return json.loads((VECTORS / "meta.json").read_text())


def load_hex(name):
    return [int(l, 16) for l in (VECTORS / name).read_text().split() if l]


import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge

META = load_meta()
CLK_NS = float(json.loads((ROOT / "config.json").read_text()).get("CLOCK_PERIOD", 10.0))


class Accel:
    def __init__(self, dut):
        self.dut = dut
        self.m = META
        self.mem, self.wmem = {}, {}

    @classmethod
    async def new(cls, dut):
        self = cls(dut)
        for h in dut:
            if h._name.startswith("i_"):
                h.value = 0
        cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
        await self.reset()
        cocotb.start_soon(self._axi_rd())
        cocotb.start_soon(self._axi_wr())
        return self

    async def reset(self):
        self.dut.rstn.value = 0
        await ClockCycles(self.dut.clk, 8)
        self.dut.rstn.value = 1
        await ClockCycles(self.dut.clk, 12)

    def _reg(self, name):
        return self.m[f"REG_{name}"]

    def ctrl(self, *names):
        return sum(1 << self.m[f"CTRL_{n}"] for n in names)

    def _bit(self, s, name):
        return (s >> self.m[f"ST_{name}"]) & 1

    def _field(self, s, name, bits):
        return (s >> self.m[f"ST_{name}"]) & ((1 << bits) - 1)

    async def wr(self, reg, data):
        d = self.dut
        await RisingEdge(d.clk)
        d.i_s_axil_awaddr.value = self._reg(reg)
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
        d.i_s_axil_araddr.value = self._reg(reg)
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

    async def _axi_rd(self):
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

    async def _axi_wr(self):
        d = self.dut
        beats = self.m["TILE_BEATS"]
        while True:
            while not d.o_m_axi_awvalid.value:
                await RisingEdge(d.clk)
            addr = int(d.o_m_axi_awaddr.value)
            d.i_m_axi_awready.value = 1
            await RisingEdge(d.clk)
            d.i_m_axi_awready.value = 0
            d.i_m_axi_wready.value = 1
            n = 0
            while n < beats:
                await ReadOnly()
                fired = bool(d.o_m_axi_wvalid.value)
                data = int(d.o_m_axi_wdata.value) if fired else 0
                await RisingEdge(d.clk)
                if fired:
                    self.wmem[addr + 4 * n] = data
                    n += 1
            d.i_m_axi_wready.value = 0
            d.i_m_axi_bvalid.value = 1
            while True:
                await ReadOnly()
                done = bool(d.o_m_axi_bready.value)
                await RisingEdge(d.clk)
                if done:
                    break
            d.i_m_axi_bvalid.value = 0

    async def check(self):
        s = await self.rd("STATUS")
        assert not self._bit(s, "DMA_ERR"), hex(s)
        assert not self._bit(s, "WDMA_ERR"), hex(s)
        assert not self._bit(s, "RES_OVF"), hex(s)
        return s

    async def wait_tiles(self, n):
        bits = 4
        mask = (1 << bits) - 1
        seen = prev = 0
        for _ in range(400 * n + 4000):
            cnt = self._field(await self.check(), "TILE_LSB", bits)
            seen += (cnt - prev) & mask
            prev = cnt
            if seen >= n:
                return
            await RisingEdge(self.dut.clk)
        raise TimeoutError(f"tiles {seen}/{n}")

    def load_stim(self):
        src = self.m["SRC_BASE"]
        for i, w in enumerate(load_hex("stim.hex")):
            self.mem[src + 4 * i] = w

    def check_golden(self, dst):
        n, rw, tb = self.m["MATRIX_SIZE"], self.m["RESULT_W"], self.m["TILE_BEATS"]
        gold = load_hex("golden.hex")
        for t in range(self.m["TILES"]):
            got_w = [self.wmem[dst + 4 * (t * tb + i)] for i in range(tb)]
            exp_w = gold[t * tb:(t + 1) * tb]
            assert got_w == exp_w, f"tile {t}: {got_w} != {exp_w}"


@cocotb.test()
async def test_generated_stream(dut):
    """Same stimulus as tb_top: stim.hex / golden.hex from gen_vectors."""
    acc = await Accel.new(dut)
    m = acc.m
    acc.load_stim()
    dst = m["ALT_DST"]
    await acc.wr("CTRL", acc.ctrl("EN"))
    await acc.wr("DST_ADDR", dst)
    await acc.wr("SRC_ADDR", m["SRC_BASE"])
    await acc.wr("LEN", m["WEIGHTS_JOB"])
    await acc.wr("NJOBS", m["TILES"] - 1)
    await acc.wr("CTRL", acc.ctrl("EN", "LOAD_W", "AUTO_ST"))
    await acc.wr("CTRL", acc.ctrl("EN", "LOAD_W", "AUTO_ST", "GO"))
    for _ in range(500):
        s = await acc.check()
        if acc._bit(s, "W_VALID") and not acc._bit(s, "CTRL_BUSY"):
            break
        await RisingEdge(dut.clk)
    await acc.wr("SRC_ADDR", m["SRC_BASE"] + 4 * m["WEIGHTS_JOB"])
    await acc.wr("LEN", m["TILE_WORDS"])
    await acc.wr("CTRL", acc.ctrl("EN", "AUTO_ST", "AUTO_FILL"))
    await acc.wait_tiles(m["TILES"])
    acc.check_golden(dst)


@cocotb.test()
async def test_bad_descriptor(dut):
    acc = await Accel.new(dut)
    await acc.wr("SRC_ADDR", acc.m["SRC_BASE"])
    await acc.wr("LEN", 0)
    await acc.wr("CTRL", acc.ctrl("EN", "LOAD_W"))
    await acc.wr("CTRL", acc.ctrl("EN", "LOAD_W", "GO"))
    await ClockCycles(dut.clk, 20)
    assert acc._bit(await acc.rd("STATUS"), "DMA_ERR")


if __name__ == "__main__":
    from gen_vectors import write_vectors
    write_vectors()
    from cocotb_tools.runner import get_runner
    sources = rtl_sources()
    runner = get_runner("icarus")
    kw = dict(hdl_toplevel="top", build_dir=ROOT / "build" / "cocotb",
              timescale=("1ps", "1ps"), waves=True)
    runner.build(sources=sources, build_args=["-g2012"], always=True, **kw)
    runner.test(test_module="test_top", test_dir=ROOT / "tb", **kw)
