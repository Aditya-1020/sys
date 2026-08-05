#!/usr/bin/env python3
import re, pathlib
HERE = pathlib.Path(__file__).resolve().parent.parent / "sram22_64x32m4w8"
OUT  = HERE / "patched"; OUT.mkdir(exist_ok=True)
for lib in sorted(HERE.glob("sram22_64x32m4w8_*.lib")):
    t = lib.read_text()
    t, n1 = re.subn(r"(default_max_transition\s*:\s*)0\.04",  r"\g<1>1.5", t)
    t, n2 = re.subn(r"(^[\t ]*max_transition\s*:\s*)0\.351", r"\g<1>1.5", t, flags=re.M)
    assert n1 and n2, lib.name
    (OUT / lib.name).write_text(t)
    print(f"{lib.name}: {n1} default, {n2} pin max_transition rewritten")