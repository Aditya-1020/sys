#!/usr/bin/env python3
import re, pathlib

HERE = pathlib.Path(__file__).resolve().parent.parent / "sram22_64x32m4w8"
OUT  = HERE / "patched"; OUT.mkdir(exist_ok=True)

VALUES = r'{}\s*\([^)]*\)\s*\{{.*?values\s*\((.*?)\);'


def fix_rstb_hold(t, name):
    i = t.index("pin (rstb) {")
    j = t.index("pin (", i + 12)
    blk = t[i:j]

    h0 = blk.index("timing_type : hold_rising;")
    h1 = blk.index("timing ()", h0)
    hold = blk[h0:h1]

    rise = re.search(VALUES.format("rise_constraint"), hold, re.S)
    fall = re.search(VALUES.format("fall_constraint"), hold, re.S)
    assert rise and fall, f"{name}: rstb hold_rising constraint tables not found"

    before = float(fall.group(1).strip().split('"')[1].split(",")[0])
    after  = float(rise.group(1).strip().split('"')[1].split(",")[0])
    assert before > after, f"{name}: rstb fall hold {before} already <= rise {after}"

    hold = hold[:fall.start(1)] + rise.group(1) + hold[fall.end(1):]
    return t[:i] + blk[:h0] + hold + blk[h1:] + t[j:], before, after


for lib in sorted(HERE.glob("sram22_64x32m4w8_*.lib")):
    t = lib.read_text()
    t, n1 = re.subn(r"(default_max_transition\s*:\s*)0\.04",  r"\g<1>1.5", t)
    t, n2 = re.subn(r"(^[\t ]*max_transition\s*:\s*)0\.351", r"\g<1>1.5", t, flags=re.M)
    assert n1 and n2, lib.name          # table indexes use index_linear(...), never matched
    t, before, after = fix_rstb_hold(t, lib.name)
    (OUT / lib.name).write_text(t)
    print(f"{lib.name}: {n1} default, {n2} pin max_transition rewritten; "
          f"rstb hold fall {before} -> {after}")
