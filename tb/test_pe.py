import cocotb
from cocotb.triggers import RisingEdge, Timer
from dataclasses import dataclass
from collections import deque
from cocotb_utils import start_clock, reset

PIPELINE_LATENCY = 2
IDLE = dict(acc_en_i=0, acc_rst_i=0, input_i=0, weight_i=0, top_input_i=0)

@dataclass(frozen=True)
class Vector:
    acc_en: int
    acc_rst: int
    input: int
    weight: int
    top_input: int

def golden_ref(v: Vector) -> int:
    if v.acc_rst:
        return 0
    if v.acc_en:
        return v.input * v.weight + v.top_input
    return v.top_input

async def drive_dut(dut, v: Vector):
    dut.acc_en_i.value = v.acc_en
    dut.acc_rst_i.value = v.acc_rst
    dut.input_i.value = v.input
    dut.weight_i.value = v.weight
    dut.top_input_i.value = v.top_input


async def reset_dut(dut, cycles=4):
    await reset(dut, idle=IDLE, cycles=cycles)

@cocotb.test()
async def test_pe_acc(dut):
    await start_clock(dut)
    await reset_dut(dut)

    vectors = [
        Vector(1, 0, 0, 0, 0),
        Vector(1, 0, 4, 3, 0),
        Vector(1, 0, 4, 3, 5),
        Vector(1, 1, 4, 3, 5),
        Vector(1, 0, 5, 3, 5),
        Vector(1, 0, -9, 3, 0),
        Vector(0, 0, 7, 9, 12),
    ]

    expected_q = deque([0] * PIPELINE_LATENCY)

    for i, v in enumerate(vectors):
        await drive_dut(dut, v)
        expected_q.append(golden_ref(v))

        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        expected = expected_q.popleft()
        actual = dut.output_o.value.to_signed()

        dut._log.info(f"cycle={i} in={v.input} w={v.weight} top={v.top_input} out={actual}")

        assert actual == expected, (
            f"cycle {i}: in={v.input}, w={v.weight}, top={v.top_input}, "
            f"expected={expected}, got={actual}"
        )

    flush_v = Vector(0, 0, 0, 0, 0)
    for j in range(PIPELINE_LATENCY):
        await drive_dut(dut, flush_v)
        expected_q.append(golden_ref(flush_v))

        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        expected = expected_q.popleft()
        actual = dut.output_o.value.to_signed()

        dut._log.info(f"flush={j} out={actual}")
        
        assert actual == expected, (f"flush {j}: expected={expected}, got={actual}")