import sys
from pathlib import Path

from cocotb_tools.runner import get_runner

ROOT = Path(__file__).resolve().parent.parent
SOURCES = sorted((ROOT / "verilog_sv2v").glob("*.v")) + [ROOT / "rtl" / "sram22_64x32m4w8.v"]

if not (ROOT / "verilog_sv2v" / "top.v").exists():
    sys.exit("verilog_sv2v/top.v missing -- run 'make sv2v_rtl' first")

runner = get_runner("icarus")
runner.build(
    verilog_sources=SOURCES,
    hdl_toplevel="top",
    build_dir=ROOT / "build" / "cocotb",
    timescale=("1ps", "1ps"),
    always=True,
    waves=True,
)
runner.test(
    hdl_toplevel="top",
    test_module="test_top",
    test_dir=ROOT / "tb",
    build_dir=ROOT / "build" / "cocotb",
    timescale=("1ps", "1ps"),
    waves=True,
)
