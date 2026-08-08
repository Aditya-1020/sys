import os
import numpy as np
import cocotb
from cocotb.triggers import ReadOnly, RisingEdge
import test_top as T

TILES = int(os.environ.get("PROF_TILES", "40"))
BATCH = int(os.environ.get("PROF_BATCH", "1"))

AC_IDLE, AC_FETCH = 0, 1
W_IDLE, W_ADDR, W_DATA = 0, 1, 2

@cocotb.test()
async def profile(dut):
    acc = await T.Accel.new(dut)
    g = acc.g
    b, a, words = g.stream(np.random.default_rng(2), TILES)
    acc.load(T.SRC_BASE, words)

    ac, wd = dut.u_arr_ctrl, dut.u_wdma
    c = dict.fromkeys(("n", "ac_idle", "ac_fetch", "arr_busy", "dma_busy", "wdma_idle", "wdma_addr", "wdma_data", "wdma_busy", "no_room", "no_fill"), 0)
    bursts, gap_max, gap_cur, gap_run, prev_busy = 0, 0, 0, 0, 0
    running = True

    async def sample():
        nonlocal bursts, gap_max, gap_cur, gap_run, prev_busy
        while running:
            await RisingEdge(dut.clk)
            await ReadOnly()
            s = int(ac.current_state.value)
            w = int(wd.current_state.value)
            c["n"] += 1
            c["ac_idle"] += s == AC_IDLE
            c["ac_fetch"] += s == AC_FETCH
            c["arr_busy"] += int(dut.array_busy.value)
            c["dma_busy"] += int(dut.dma_busy.value)
            c["wdma_idle"] += w == W_IDLE
            c["wdma_addr"] += w == W_ADDR
            c["wdma_data"] += w == W_DATA
            busy = int(dut.wdma_busy.value)
            c["wdma_busy"] += busy

            if int(dut.wdma_resp.value):
                bursts += 1
            if not busy:
                gap_cur += 1
                gap_run += 1
                gap_max = max(gap_max, gap_run)
            else:
                gap_run = 0
            prev_busy = busy
            c["no_room"] += int(dut.fifo_room.value) == 0
            c["no_fill"] += (s == AC_IDLE) and int(dut.dma_fill_done.value) == 0

    cocotb.start_soon(sample())
    t0 = acc.cycles()
    await acc.run_chained(T.DST_BASE, TILES, batch=BATCH)
    total = acc.cycles() - t0
    running = False

    T.check_tiles(acc, a, b, T.DST_BASE, "prof")

    n = c["n"] or 1
    ideal = g.n
    log = dut._log.info
    log("=" * 62)

    log(f"{TILES} tiles, batch={BATCH}: {total:.0f} cycles = {total / TILES:.2f} cyc/tile")
    log(f"array-limited floor ~{ideal} cyc/tile  ->  {total / TILES / ideal:.1f}x off")

    log(f"store-limited floor {c['wdma_busy'] / TILES:.2f} cyc/tile " f"({g.tile_beats} beats/tile, {g.elems}x{g.result_w}b tight-packed)")
    log("-" * 62)

    log(f"{'signal':<14}{'cycles':>9}{'% of run':>10}{'per tile':>11}")

    for k in ("ac_idle", "ac_fetch", "arr_busy", "dma_busy", "wdma_idle", "wdma_addr", "wdma_data", "wdma_busy", "no_room", "no_fill"):
        log(f"{k:<14}{c[k]:>9d}{100.0 * c[k] / n:>9.1f}%{c[k] / TILES:>11.2f}")
    
    if bursts:
        log(f"store idle {gap_cur / bursts:.2f} cyc/burst waiting for a tile " f"(longest run {gap_max}) over {bursts} bursts")
    log("=" * 62)


if __name__ == "__main__":
    from cocotb_tools.runner import get_runner

    runner = get_runner("icarus")
    kw = dict(hdl_toplevel="top", build_dir=T.ROOT / "build" / "prof", timescale=("1ps", "1ps"), waves=False)
    params = {k: int(os.environ[k]) for k in ("RES_JOBS",) if os.environ.get(k)}
    runner.build(sources=T.rtl_sources(), build_args=["-g2012"], parameters=params, always=True, **kw)
    runner.test(test_module="prof", test_dir=T.ROOT / "tb", **kw)
