import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge
from cocotb.utils import get_sim_time
import numpy as np

CTRL = 0x00
STATUS = 0x04
SRC = 0x08
LEN = 0x0C
RESULT = 0x10
DST = 0x14

EN= 1 << 0
GO = 1<< 1
LOAD_W = 1 << 2
STORE = 1 << 3
AUTO_ST = 1 << 4
DMA_BUSY = 1 << 0
DMA_ERR = 1 << 2
RES_OVF = 1 << 10
WDMA_DONE = 1 << 12
WDMA_ERR = 1 << 13
LEVEL_LSB = 16
TILE_LSB = 22

N = 4
RESULT_BITS = 18
CLK_NS = 10
MACS_PER_JOB = N * N * N
MEM = []
WMEM = {}
WBURST = []

JOBS = []
BENCH_T0 = 0

def cycles():
	return get_sim_time("ns") / CLK_NS

def pack(m):
	return np.ascontiguousarray(m, dtype=np.int8).view(np.uint32).ravel().tolist()

def sign_extend_result(raw):
	raw &= (1 << RESULT_BITS) - 1
	return raw - (1 << RESULT_BITS) if raw >> (RESULT_BITS - 1) else raw

async def memory(dut):
	dut.i_m_axi_arready.value = 0
	dut.i_m_axi_rvalid.value = 0
	dut.i_m_axi_rlast.value = 0
	dut.i_m_axi_rresp.value = 0

	while True:
		while not dut.o_m_axi_arvalid.value:
			await RisingEdge(dut.clk)
		beats = int(dut.o_m_axi_arlen.value) + 1
		dut.i_m_axi_arready.value = 1
		await RisingEdge(dut.clk)
		dut.i_m_axi_arready.value = 0

		for i in range(beats):
			dut.i_m_axi_rdata.value = MEM[i] if i < len(MEM) else 0
			dut.i_m_axi_rvalid.value = 1
			dut.i_m_axi_rlast.value = int(i == beats - 1)
			await RisingEdge(dut.clk)
			while not dut.o_m_axi_rready.value:
				await RisingEdge(dut.clk)
		dut.i_m_axi_rvalid.value = 0
		dut.i_m_axi_rlast.value = 0


async def memory_write(dut):
	dut.i_m_axi_awready.value = 0
	dut.i_m_axi_wready.value = 0
	dut.i_m_axi_bvalid.value = 0
	dut.i_m_axi_bresp.value = 0

	while True:
		while not dut.o_m_axi_awvalid.value:
			await RisingEdge(dut.clk)
		t_aw = cycles()
		addr = int(dut.o_m_axi_awaddr.value)
		beats = int(dut.o_m_axi_awlen.value) + 1
		dut.i_m_axi_awready.value = 1
		await RisingEdge(dut.clk)
		dut.i_m_axi_awready.value = 0

		dut.i_m_axi_wready.value = 1
		n = 0
		while n < beats:
			await ReadOnly()
			fired = bool(dut.o_m_axi_wvalid.value)
			data = int(dut.o_m_axi_wdata.value) if fired else 0
			last = bool(dut.o_m_axi_wlast.value)
			await RisingEdge(dut.clk)
			if fired:
				WMEM[addr + 4 * n] = data
				n += 1
				assert last == (n == beats), f"wlast at beat {n} of {beats}"
		dut.i_m_axi_wready.value = 0

		dut.i_m_axi_bvalid.value = 1
		while True:
			await ReadOnly()
			done = bool(dut.o_m_axi_bready.value)
			await RisingEdge(dut.clk)
			if done:
				break
		dut.i_m_axi_bvalid.value = 0
		WBURST.append(cycles() - t_aw)


async def csr_write(dut, addr, data):
	await RisingEdge(dut.clk)
	dut.i_s_axil_awaddr.value = addr
	dut.i_s_axil_awvalid.value = 1
	dut.i_s_axil_wdata.value = data
	dut.i_s_axil_wstrb.value = 0xF
	dut.i_s_axil_wvalid.value = 1
	dut.i_s_axil_bready.value = 1

	aw = w = False
	while not (aw and w):
		await RisingEdge(dut.clk)
		if not aw and dut.o_s_axil_awready.value:
			dut.i_s_axil_awvalid.value = 0
			aw = True
		if not w and dut.o_s_axil_wready.value:
			dut.i_s_axil_wvalid.value = 0
			w = True
	while not dut.o_s_axil_bvalid.value:
		await RisingEdge(dut.clk)
	await RisingEdge(dut.clk)
	dut.i_s_axil_bready.value = 0


async def csr_read(dut, addr):
	await RisingEdge(dut.clk)
	dut.i_s_axil_araddr.value = addr
	dut.i_s_axil_arvalid.value = 1
	dut.i_s_axil_rready.value = 1

	while True:
		await RisingEdge(dut.clk)
		if dut.o_s_axil_arready.value:
			dut.i_s_axil_arvalid.value = 0
			break
	while not dut.o_s_axil_rvalid.value:
		await RisingEdge(dut.clk)
	data = int(dut.o_s_axil_rdata.value)
	await RisingEdge(dut.clk)
	dut.i_s_axil_rready.value = 0
	return data


async def setup(dut):
	global BENCH_T0
	cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
	for sig in ("i_s_axil_awaddr", "i_s_axil_awvalid", "i_s_axil_wdata", "i_s_axil_wstrb", "i_s_axil_wvalid", "i_s_axil_bready",
				"i_s_axil_araddr", "i_s_axil_arvalid", "i_s_axil_rready", "i_m_axi_arready", "i_m_axi_rdata", "i_m_axi_rresp",
				"i_m_axi_rlast", "i_m_axi_rvalid", "i_m_axi_awready", "i_m_axi_wready", "i_m_axi_bresp", "i_m_axi_bvalid"):
		getattr(dut, sig).value = 0

	dut.rstn.value = 0
	await ClockCycles(dut.clk, 8)
	dut.rstn.value = 1
	await ClockCycles(dut.clk, 8)

	cocotb.start_soon(memory(dut))
	cocotb.start_soon(memory_write(dut))
	BENCH_T0 = cycles()


async def program_job(dut, words, load_w, src=0x1000, extra=0):
	ctrl = EN | (LOAD_W if load_w else 0) | extra
	await csr_write(dut, SRC, src)
	await csr_write(dut, LEN, words)
	await csr_write(dut, CTRL, ctrl)
	await csr_write(dut, CTRL, ctrl | GO)


async def wait_result(dut, timeout=500):
	for _ in range(timeout):
		status = await csr_read(dut, STATUS)
		assert not status & DMA_ERR, f"DMA error, STATUS=0x{status:08x}"
		assert not status & RES_OVF, f"result fifo overflow, STATUS=0x{status:08x}"
		if ((status >> LEVEL_LSB) & 0x3F) >= N * N:
			return
		await RisingEdge(dut.clk)
	raise TimeoutError(f"no result after {timeout} polls, STATUS=0x{status:08x}")


async def run_job(dut, words, load_w, src=0x1000, timeout=500):
	await program_job(dut, words, load_w, src)
	await wait_result(dut, timeout)


async def read_results(dut):
	vals = [sign_extend_result(await csr_read(dut, RESULT)) for _ in range(N * N)]
	return np.array(vals, dtype=np.int32).reshape(N, N)


async def read_results_burst(dut):
	await RisingEdge(dut.clk)
	dut.i_s_axil_araddr.value = RESULT
	dut.i_s_axil_arvalid.value = 1
	dut.i_s_axil_rready.value = 1

	vals, sent = [], 0
	while len(vals) < N * N:
		await ReadOnly()
		ar_fire = bool(dut.i_s_axil_arvalid.value) and bool(dut.o_s_axil_arready.value)
		if bool(dut.o_s_axil_rvalid.value):
			vals.append(sign_extend_result(int(dut.o_s_axil_rdata.value)))
		await RisingEdge(dut.clk)
		if ar_fire:
			sent += 1
			if sent == N * N:
				dut.i_s_axil_arvalid.value = 0
	dut.i_s_axil_rready.value = 0
	return np.array(vals, dtype=np.int32).reshape(N, N)


async def store_results(dut, dst=0x2000, ctrl=EN | GO, timeout=500):
	WMEM.clear()
	await csr_write(dut, DST, dst)
	await csr_write(dut, CTRL, ctrl)
	await csr_write(dut, CTRL, ctrl | STORE)

	for _ in range(timeout):
		status = await csr_read(dut, STATUS)
		assert not status & WDMA_ERR, f"store error, STATUS=0x{status:08x}"
		if status & WDMA_DONE:
			break
		await RisingEdge(dut.clk)
	else:
		raise TimeoutError(f"store never finished, STATUS=0x{status:08x}")

	vals = [sign_extend_result(WMEM[dst + 4 * i]) for i in range(N * N)]
	return np.array(vals, dtype=np.int32).reshape(N, N)


async def wait_dma_idle(dut, timeout=500):
	for _ in range(timeout):
		status = await csr_read(dut, STATUS)
		assert not status & DMA_ERR, f"dma error, STATUS=0x{status:08x}"
		if not (status & DMA_BUSY):
			return
		await RisingEdge(dut.clk)
	raise TimeoutError("dma never went idle")


async def bench_pipeline(dut, a, b, njobs, dst, auto):
	WMEM.clear()
	await csr_write(dut, DST, dst)
	if auto:
		await csr_write(dut, CTRL, EN | AUTO_ST)  # arm: reloads dst pointer, zeroes tile count
	extra = AUTO_ST if auto else 0

	t0 = cycles()
	for j in range(njobs):
		await wait_dma_idle(dut)
		MEM[:] = (pack(b) + pack(a)) if j == 0 else pack(a)
		await program_job(dut, words=8 if j == 0 else 4, load_w=(j == 0), extra=extra)
		if not auto:
			await wait_result(dut)
			await csr_write(dut, DST, dst + j * N * N * 4)
			await csr_write(dut, CTRL, EN | STORE)
			await csr_write(dut, CTRL, EN)

	for _ in range(4000):
		status = await csr_read(dut, STATUS)
		assert not status & WDMA_ERR, f"store error, STATUS=0x{status:08x}"
		assert not status & RES_OVF, f"result fifo overflow, STATUS=0x{status:08x}"
		if auto and ((status >> TILE_LSB) & 0xF) == njobs % 16:
			break
		if not auto and (status & WDMA_DONE):
			break
		await RisingEdge(dut.clk)
	else:
		raise TimeoutError(f"pipeline stalled, STATUS=0x{status:08x}")
	total = cycles() - t0

	exp = a.astype(np.int32) @ b.astype(np.int32)
	for t in range(njobs):
		base = dst + t * N * N * 4
		vals = [sign_extend_result(WMEM[base + 4 * i]) for i in range(N * N)]
		got = np.array(vals, dtype=np.int32).reshape(N, N)
		assert (got == exp).all(), f"tile {t}\ngot\n{got}\nexp\n{exp}"
	return total


async def bench_job(dut, name, words, load_w, src=0x1000, reader=read_results):
	t0 = cycles()
	await program_job(dut, words, load_w, src)
	t1 = cycles()
	await wait_result(dut)
	t2 = cycles()
	c = await reader(dut)
	t3 = cycles()
	JOBS.append((name, t1 - t0, t2 - t1, t3 - t2, t3 - t0))
	return c


def bench_report(dut):
	if not JOBS:
		return
	w = max(len(j[0]) for j in JOBS + [("job", 0, 0, 0, 0)])
	bar = "-" * (w + 36)
	out = ["", f"{'job':<{w}} {'program':>8} {'compute':>8} {'readout':>8} {'total':>8}  cycles", bar]
	for name, prog, comp, rd, tot in JOBS:
		out.append(f"{name:<{w}} {prog:>8.0f} {comp:>8.0f} {rd:>8.0f} {tot:>8.0f}")

	sp, sc, sr, st = (sum(j[i] for j in JOBS) for i in (1, 2, 3, 4))
	out += [bar,
		f"{'total':<{w}} {sp:>8.0f} {sc:>8.0f} {sr:>8.0f} {st:>8.0f}",
		f"{'':<{w}} {sp/st:>8.0%} {sc/st:>8.0%} {sr/st:>8.0%}"]

	elapsed = cycles() - BENCH_T0
	macs = MACS_PER_JOB * len(JOBS)
	if WBURST:
		out += ["", f"store dma  aw->bresp {min(WBURST):.0f} cycles for {N*N} beats " f"(the rest of 'readout' is csr ceremony)"]
	out += ["", f"elapsed  {elapsed:.0f} cycles = {elapsed*CLK_NS:.0f} ns @ {1000/CLK_NS:.0f} MHz "
			f"({elapsed-st:.0f} outside jobs)",
			f"compute  {macs} MACs / {st:.0f} job cycles = {macs/st:.2f} MAC/cycle (peak {N*N})"]
	dut._log.info("\n".join(out))


@cocotb.test()
async def test_matmul(dut):
	rng = np.random.default_rng(1)
	a1 = rng.integers(-128, 128, (N, N), dtype=np.int8)
	a2 = rng.integers(-128, 128, (N, N), dtype=np.int8)
	b = rng.integers(-128, 128, (N, N), dtype=np.int8)
	ref = lambda a: a.astype(np.int32) @ b.astype(np.int32)

	await setup(dut)

	MEM[:] = pack(b) + pack(a1)
	got = await bench_job(dut, "A1xB load_w", words=8, load_w=True)
	assert (got == ref(a1)).all(), f"\ngot\n{got}\nexp\n{ref(a1)}"
	dut._log.info(f"A1 x B =\n{got}")

	MEM[:] = pack(a2)
	got = await bench_job(dut, "A2xB reuse", words=4, load_w=False)
	assert (got == ref(a2)).all(), f"\ngot\n{got}\nexp\n{ref(a2)}"
	dut._log.info(f"A2 x B =\n{got}")

	got = await bench_job(dut, "A2xB burst rd", words=4, load_w=False, reader=read_results_burst)
	assert (got == ref(a2)).all(), f"\ngot\n{got}\nexp\n{ref(a2)}"

	got = await bench_job(dut, "A2xB store dma", words=4, load_w=False, reader=store_results)
	assert (got == ref(a2)).all(), f"\ngot\n{got}\nexp\n{ref(a2)}"

	bench_report(dut)

	K = 8
	ser = await bench_pipeline(dut, a2, b, njobs=K, dst=0x3000, auto=False)
	aut = await bench_pipeline(dut, a2, b, njobs=K, dst=0x4000, auto=True)
	dut._log.info(
		f"\npipeline, {K} jobs back-to-back\n"
		f"  cpu-sequenced store  {ser:.0f} cycles  ({ser/K:.1f}/job, {MACS_PER_JOB*K/ser:.2f} MAC/cyc)\n"
		f"  hw auto-chained      {aut:.0f} cycles  ({aut/K:.1f}/job, {MACS_PER_JOB*K/aut:.2f} MAC/cyc)\n"
		f"  speedup              {ser/aut:.2f}x")
