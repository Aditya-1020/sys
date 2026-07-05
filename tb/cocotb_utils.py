import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

async def start_clock(dut, period_ns=10):
    cocotb.start_soon(Clock(dut.clk, period_ns, unit="ns").start())

async def reset(dut, idle=None, cycles=2):
    """
    reset dut for 'cycles' cycles driving any {signal_name: value} pairs 
    in idle then release rst with settle time
    """
    dut.rstn.value = 0
    for name, value in (idle or {}).items():
        getattr(dut, name).value = value
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)

def index2d(handle, r, c, ncols):
    """Index a 2D unpacked-array port. Icarus flattens unpacked dimensions
    into a single array instead of nesting handles, so handle[r][c] raises;
    fall back to the flattened, row-major index."""
    try:
        return handle[r][c]
    except TypeError:
        return handle[r * ncols + c]

def flat2d(rows):
    """Flatten a 2D sequence into the row-major layout cocotb expects when
    assigning a whole 2D unpacked-array port at once."""
    return [int(v) for row in rows for v in row]
