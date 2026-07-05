import cocotb
from cocotb.triggers import RisingEdge, FallingEdge
import numpy as np

from cocotb_utils import start_clock, reset, index2d, flat2d
from test_pe import PIPELINE_LATENCY
"""
weight-stationary streaming array:
one input vector per cycle -> one result vector per cycle at row N-1,
FILL_LATENCY cycles later. vecmat = matmul with M=1.
"""

N = 2
XLEN = 8
OUTPUT_WIDTH = 32
FILL_LATENCY = N * PIPELINE_LATENCY

IDLE = {
    "acc_en_i": 0,
    "acc_rst_i": 0,
    "input_row": [0] * N,
    "weight_arr": [0] * (N * N),
}


def ref(A, W):
    return np.atleast_2d(np.asarray(A, dtype=np.int64)) @ np.asarray(W, dtype=np.int64)

async def reset_dut(dut, cycles=2):
    await reset(dut, idle=IDLE, cycles=cycles)

def drive_row(dut, x):
    for r in range(N):
        dut.input_row[r].value = int(x[r])

def sample_bottom(dut):
    row = []
    for c in range(N):
        v = index2d(dut.output_arr, N - 1, c, N).value
        row.append(v.to_signed() if v.is_resolvable else None)
    return row

async def run_case(dut, A, W):
    A = np.atleast_2d(np.asarray(A))
    exp = ref(A, W)
    M = A.shape[0]
    dut.weight_arr.value = flat2d(W)
    dut.acc_rst_i.value = 0
    buf = []
    for t in range(M + FILL_LATENCY + 2):
        if t < M:
            drive_row(dut, A[t])
            dut.acc_en_i.value = 1
        else:
            drive_row(dut, [0] * N)
            dut.acc_en_i.value = 0
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        buf.append(sample_bottom(dut))
    got = [buf[i + FILL_LATENCY - 1] for i in range(M)]
    assert got == exp.tolist(), (
        f"got {got}, exp {exp.tolist()}  "
        f"(A={A.tolist()}, W={np.asarray(W).tolist()}, stream={buf})"
    )


@cocotb.test()
async def test_vecmat(dut):
    await start_clock(dut)
    await reset_dut(dut)

    await run_case(dut, np.array([1, 2]), np.array([[3, 4], [5, 6]]))
    await reset_dut(dut)
    await run_case(dut, np.array([-5, 7]), np.array([[-2, 3], [4, -6]]))
    await reset_dut(dut)
    await run_case(dut, np.array([-128, -128]), np.array([[-128, -128], [-128, -128]]))
    await reset_dut(dut)


@cocotb.test()
async def test_streaming_matmul(dut):
    await start_clock(dut)
    await reset_dut(dut)

    await run_case(dut, np.array([[-9, 2], [7, -27]]), np.array([[17, 27], [7, 6]]))
    await reset_dut(dut)
    await run_case(dut, np.array([[1, 0], [0, 1], [2, 3]]), np.array([[5, 6], [7, 8]]))
    await reset_dut(dut)

    for _ in range(50):
        M = np.random.randint(1, 5)
        A = np.random.randint(-128, 128, (M, N))
        W = np.random.randint(-128, 128, (N, N))
        await run_case(dut, A, W)
        await reset_dut(dut)
