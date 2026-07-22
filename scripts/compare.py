#!/usr/bin/env python3
"""Tabulate LibreLane signoff metrics side-by-side across runs.

Usage:
    python3 scripts/compare.py                 # all runs/sweep_*
    python3 scripts/compare.py runs/sweep_*    # explicit globs / dirs
    python3 scripts/compare.py runs/sweep_03 runs/RUN_2026-07-20_18-10-47

Reads <run>/final/metrics.json from each run and prints one column per run.
"* " marks the best value in a row (smaller die/DRC/wirelength, larger slack).
Runs without a final/metrics.json (e.g. a flow that failed early) are skipped
with a note. Magic DRC is shown but excluded from the sign-off verdict (the
SRAM GDS trips millions of known-benign magic errors).
"""
import glob
import json
import math
import os
import sys

# key, label, kind, better-direction ("min"/"max"/None). "@" keys are derived.
SPEC = [
    ("design__die__area",                      "die area (um^2)", "int", "min"),
    ("@die_side",                              "die side (um)",   "int", "min"),
    ("design__instance__utilization__stdcell", "std-cell util",   "pct", None),
    ("design__instance__utilization",          "instance util",   "pct", None),
    ("route__wirelength",                      "route wirelen",   "int", "min"),
    ("timing__setup__ws",                      "setup WNS (ns)",  "ns",  "max"),
    ("timing__setup__tns",                     "setup TNS (ns)",  "ns",  "max"),
    ("timing__hold__ws",                       "hold WNS (ns)",   "ns",  "max"),
    ("route__drc_errors",                      "route DRC",       "int", "min"),
    ("klayout__drc_error__count",              "klayout DRC",     "int", "min"),
    ("magic__drc_error__count",                "magic DRC (fyi)", "int", None),
    ("antenna__violating__nets",               "antenna nets",    "int", "min"),
    ("design__max_slew_violation__count",      "max-slew viol",   "int", "min"),
    ("design__max_cap_violation__count",       "max-cap viol",    "int", "min"),
    ("@signoff",                               "signs off?",      "str", None),
]


def load(run):
    p = os.path.join(run, "final", "metrics.json")
    if not os.path.isfile(p):
        return None
    try:
        with open(p) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def num(m, k):
    v = m.get(k)
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def derive(key, m):
    if key == "@die_side":
        a = num(m, "design__die__area")
        return math.sqrt(a) if a and a > 0 else None
    if key == "@signoff":
        sw, hw = num(m, "timing__setup__ws"), num(m, "timing__hold__ws")
        checks = [
            sw is not None and sw >= 0,
            hw is not None and hw >= 0,
            (num(m, "route__drc_errors") or 0) == 0,
            (num(m, "klayout__drc_error__count") or 0) == 0,
            (num(m, "antenna__violating__nets") or 0) == 0,
        ]
        return "YES" if all(checks) else "NO"
    return num(m, key)


def raw(key, m):
    return derive(key, m) if key.startswith("@") else num(m, key)


def fmt(kind, v):
    if v is None:
        return "-"
    if kind == "str":
        return str(v)
    if kind == "pct":
        return f"{v * 100:.1f}%"
    if kind == "ns":
        return f"{v:+.3f}"
    return f"{v:,.0f}"  # int


def main(argv):
    pats = argv[1:] or ["runs/sweep_*"]
    runs, seen = [], set()
    for pat in pats:
        for d in sorted(glob.glob(pat)):
            if os.path.isdir(d) and d not in seen:
                seen.add(d)
                runs.append(d)

    cols, skipped = [], []
    for d in runs:
        m = load(d)
        (cols.append((os.path.basename(d), m)) if m else skipped.append(d))

    if not cols:
        print("compare: no runs with final/metrics.json found for "
              f"{pats} (skipped: {', '.join(skipped) or 'none'})")
        return 1

    # precompute formatted cells + per-row best index
    label_w = max(len(lbl) for _, lbl, _, _ in SPEC)
    rows = []
    for key, lbl, kind, direction in SPEC:
        vals = [raw(key, m) for _, m in cols]
        best = None
        if direction and any(v is not None for v in vals):
            nums = [v for v in vals if v is not None]
            tgt = min(nums) if direction == "min" else max(nums)
            best = tgt
        cells = []
        for v in vals:
            s = fmt(kind, v)
            if best is not None and v == best and len([1 for x in vals if x == best]) < len(vals):
                s += " *"
            cells.append(s)
        rows.append((lbl, cells))

    col_w = [max(len(name), max(len(r[1][i]) for r in rows)) + 1
             for i, (name, _) in enumerate(cols)]

    def line(label, cells):
        out = label.ljust(label_w) + " |"
        for c, w in zip(cells, col_w):
            out += " " + c.rjust(w)
        return out

    print()
    print(line("metric", [name for name, _ in cols]))
    print("-" * (label_w + 2 + sum(w + 1 for w in col_w)))
    for lbl, cells in rows:
        print(line(lbl, cells))
    if skipped:
        print(f"\n  skipped (no metrics.json): {', '.join(skipped)}")
    print("\n  * = best in row.  Sign-off needs setup/hold WNS >= 0 and "
          "route/klayout DRC + antenna = 0.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
