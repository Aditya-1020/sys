#!/usr/bin/env python3
"""Summarize a LibreLane run without digging through the run directory.

Reads final/metrics.json (or the last step's state_out.json for crashed runs)
plus every *-openroad-sta* step's reports and prints:
  1. signoff wall     - PASS/FAIL for DRC, LVS, XOR, antenna, timing checkers
  2. timing models    - corner -> liberty/RC models, which STA stages ran each
  3. per-corner table - setup/hold WS/TNS/violation counts for all corners
  4. timing evolution - worst slack per PVT at every STA stage (synth -> pnr)
  5. post-synth STA   - per-corner summary, worst path per corner, overlap
  6. worst paths      - top violators + worst-path detail (--stage picks step)
  7. slack histogram  - violated-path slack distribution in 1 ns buckets
  8. design stats     - area, utilization, instances, power, routing, IR drop
  9. flow warnings    - warning-code breakdown

Usage:
  scripts/runreport.py                 # latest run under runs/
  scripts/runreport.py <run-name>      # runs/<run-name> or a path
  scripts/runreport.py --paths 15 --corner nom_tt_025C_1v80
  scripts/runreport.py --stage synth   # paths/histogram from post-synth STA
  scripts/runreport.py --plain         # no color / no rich (logs, grep)
"""

import argparse
import fnmatch
import json
import re
import sys
from collections import Counter, namedtuple
from os.path import commonprefix
from pathlib import Path

# --------------------------------------------------------------------------
# rich with plain-text fallback (openlane/nix shells may lack rich)
# --------------------------------------------------------------------------
def _load_ui(plain):
    if not plain:
        try:
            from rich.console import Console
            from rich.table import Table
            from rich.text import Text
            # piped output defaults to width 80, which crops the corner table
            width = None if sys.stdout.isatty() else 120
            return Console(width=width), Table, Text
        except ImportError:
            pass

    class Text(str):
        def __new__(cls, s, style=""):
            return super().__new__(cls, s)

    class Table:
        def __init__(self, title=None, **kw):
            self.title, self.cols, self.rows = title, [], []

        def add_column(self, header, **kw):
            self.cols.append(str(header))

        def add_row(self, *cells, **kw):
            self.rows.append([str(c) for c in cells])

        def __str__(self):
            w = [len(c) for c in self.cols]
            for r in self.rows:
                for i, c in enumerate(r):
                    w[i] = max(w[i], len(c))
            lines = []
            if self.title:
                lines.append(self.title)
            lines.append("  ".join(c.ljust(w[i]) for i, c in enumerate(self.cols)))
            lines.append("  ".join("-" * n for n in w))
            for r in self.rows:
                lines.append("  ".join(c.ljust(w[i]) for i, c in enumerate(r)))
            return "\n".join(lines)

    class Console:
        def print(self, obj="", **kw):
            print(obj)

        def rule(self, title="", **kw):
            print(f"\n──── {title} " + "─" * max(4, 60 - len(str(title))))

    return Console(), Table, Text


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def fnum(v, prec=4):
    if v is None:
        return "—"
    if isinstance(v, float):
        return f"{v:.{prec}f}"
    return str(v)


def fmt_power(w):
    if w is None:
        return "—"
    for unit, scale in (("W", 1), ("mW", 1e-3), ("µW", 1e-6), ("nW", 1e-9)):
        if abs(w) >= scale:
            s = f"{w / scale:.3g} {unit}"
            break
    else:
        s = f"{w:.3g} W"
    if abs(w) > 1e3:
        s += "  (absurd — lib power data suspect)"
    return s


def fmt_volts(v):
    if v is None:
        return "—"
    for unit, scale in (("V", 1), ("mV", 1e-3), ("µV", 1e-6)):
        if abs(v) >= scale:
            s = f"{v / scale:.3g} {unit}"
            break
    else:
        s = f"{v:.3g} V"
    if abs(v) > 2:  # more than a sky130 rail — garbage from bad lib power data
        s += " (absurd)"
    return s


def fmt_area(um2):
    if um2 is None:
        return "—"
    if um2 >= 1e6:
        return f"{um2 / 1e6:.3f} mm²"
    return f"{um2:,.0f} µm²"


def corner_sort_key(c):
    rc_order = {"nom": 0, "min": 1, "max": 2}
    pv_order = {"tt": 0, "ss": 1, "ff": 2}
    parts = c.split("_")
    return (rc_order.get(parts[0], 9), pv_order.get(parts[1], 9), c)


def resolve_run(arg, runs_dir):
    if arg:
        p = Path(arg)
        if p.is_dir():
            return p
        p = runs_dir / arg
        if p.is_dir():
            return p
        sys.exit(f"error: run '{arg}' not found (not a path, not under {runs_dir}/)")
    if not runs_dir.is_dir():
        sys.exit(f"error: no {runs_dir}/ directory here")
    runs = [d for d in runs_dir.iterdir() if d.is_dir()]
    if not runs:
        sys.exit(f"error: no runs under {runs_dir}/")
    return max(runs, key=lambda d: d.stat().st_mtime)


def load_metrics(run_dir):
    """final/metrics.json, else metrics from the last step that has state_out."""
    final = run_dir / "final" / "metrics.json"
    if final.is_file():
        return json.loads(final.read_text()), "final"
    steps = sorted(
        (d for d in run_dir.iterdir() if d.is_dir() and re.match(r"\d+-", d.name)),
        key=lambda d: int(d.name.split("-")[0]),
        reverse=True,
    )
    for step in steps:
        so = step / "state_out.json"
        if so.is_file():
            state = json.loads(so.read_text())
            if "metrics" in state:
                return state["metrics"], step.name
    sys.exit(f"error: no metrics found in {run_dir} (no final/, no step state_out.json)")


# --------------------------------------------------------------------------
# STA stages: every *-openroad-sta* step is one timing snapshot of the flow
# --------------------------------------------------------------------------
Stage = namedtuple("Stage", "label num dir metrics")

STAGE_LABELS = {"staprepnr": "post-synth", "stapostpnr": "post-pnr"}


def find_sta_stages(run_dir):
    """All *-openroad-sta* steps in flow order, each with its metrics snapshot."""
    stages = []
    for d in run_dir.iterdir():
        m = re.match(r"(\d+)-openroad-(sta[\w-]+)$", d.name)
        if not m or not d.is_dir():
            continue
        num, kind = int(m.group(1)), m.group(2)
        label = STAGE_LABELS.get(kind, kind.replace("stamidpnr", "mid-pnr"))
        metrics = {}
        so = d / "state_out.json"
        if so.is_file():
            try:
                metrics = json.loads(so.read_text()).get("metrics", {})
            except (json.JSONDecodeError, OSError):
                pass
        stages.append(Stage(label, num, d, metrics))
    stages.sort(key=lambda s: s.num)
    return stages


def pick_stage(stages, arg):
    """--stage by exact label/step number, else substring ('synth', 'mid')."""
    if not stages:
        return None
    if not arg:
        return stages[-1]
    for s in stages:
        if arg in (str(s.num), s.label):
            return s
    matches = [s for s in stages if arg in s.label or arg in s.dir.name]
    if matches:
        return matches[-1]
    sys.exit(f"error: no STA stage matching '{arg}' "
             f"(have: {', '.join(s.label for s in stages)})")


def stage_corners(stage):
    return sorted((d.name for d in stage.dir.iterdir() if d.is_dir()),
                  key=corner_sort_key)


def stage_default_corner(stage):
    try:
        return json.loads((stage.dir / "config.json").read_text()).get("DEFAULT_CORNER")
    except (json.JSONDecodeError, OSError):
        return None


def stage_ran_corners(stage):
    """Corners a stage actually evaluated. Mid-pnr STA steps have no corner
    subdirs (reports sit flat in the step dir) and run the default corner
    only — their state_out metrics still carry stale values for the rest."""
    dirs = stage_corners(stage)
    if dirs:
        return dirs
    dc = stage_default_corner(stage)
    return [dc] if dc else []


def resolve_corner_dir(stage, corner):
    """Report dir for a corner: subdir, or the step dir itself if flat."""
    d = stage.dir / corner
    if d.is_dir():
        return d
    if not stage_corners(stage):
        return stage.dir
    return None


def stage_worst_corner(stage, m, kind):
    """Worst-WS corner among the corners this stage actually ran."""
    ran = stage_ran_corners(stage)
    best, best_v = None, None
    for c in ran:
        v = m.get(f"timing__{kind}__ws__corner:{c}")
        if v is not None and (best_v is None or v < best_v):
            best, best_v = c, v
    return best or (ran[0] if ran else None)


def pvt_worst(m, kind, pvt, corners):
    """Most negative WS over the given corners belonging to one PVT (ss/tt/ff)."""
    vals = [m.get(f"timing__{kind}__ws__corner:{c}") for c in corners
            if len(c.split("_")) > 1 and c.split("_")[1] == pvt]
    vals = [v for v in vals if v is not None]
    return min(vals) if vals else None


VIOL_RE = re.compile(r"\[(\w+) ([\w.-]+)\]\s+(\S+)\s+->\s+(\S+)\s+:\s+(-?[\d.]+)")


def parse_violators(corner_dir):
    """violator_list.rpt -> {'setup': [(start,end,slack)...], 'hold': [...]}"""
    out = {"setup": [], "hold": []}
    f = corner_dir / "violator_list.rpt"
    if not f.is_file():
        return out
    for m in VIOL_RE.finditer(f.read_text()):
        kind, _group, start, end, slack = m.groups()
        if kind in out:
            out[kind].append((start, end, float(slack)))
    for k in out:
        out[k].sort(key=lambda t: t[2])
    return out


def parse_worst_path(corner_dir, which="max"):
    """First (worst) path block of max.rpt/min.rpt: endpoints, slack, hier nets."""
    f = corner_dir / f"{which}.rpt"
    if not f.is_file():
        return None
    start = end = group = None
    slack = verdict = None
    nets = []
    in_block = False
    for line in f.read_text().splitlines():
        if line.startswith("Startpoint:"):
            if in_block:
                break  # only the first (worst) block
            in_block = True
            start = line.split()[1]
        elif in_block and line.startswith("Endpoint:"):
            end = line.split()[1]
        elif in_block and line.startswith("Path Group:"):
            group = line.split()[-1]
        elif in_block:
            m = re.match(r"^\s*(-?[\d.]+)\s+slack \((VIOLATED|MET)\)", line)
            if m:
                slack, verdict = float(m.group(1)), m.group(2)
                break
            m = re.match(r"^\s+(\S+)\s+\(net\)$", line)
            if m and "." in m.group(1):
                nets.append(m.group(1))
    if start is None:
        return None
    return {"start": start, "end": end, "group": group,
            "slack": slack, "verdict": verdict, "nets": nets}


def parse_violated_slacks(corner_dir, which="max"):
    """All 'slack (VIOLATED)' values in max.rpt/min.rpt (one per reported path)."""
    f = corner_dir / f"{which}.rpt"
    if not f.is_file():
        return []
    return [float(v) for v in
            re.findall(r"^\s*(-?[\d.]+)\s+slack \(VIOLATED\)", f.read_text(), re.M)]


# --------------------------------------------------------------------------
# sections
# --------------------------------------------------------------------------
#          label                        metric key                          severity
CHECKS = [
    ("Magic DRC",                  "magic__drc_error__count",               "hard"),
    ("KLayout DRC",                "klayout__drc_error__count",             "hard"),
    ("Routing DRC (DRT)",          "route__drc_errors",                     "hard"),
    ("LVS errors",                 "design__lvs_error__count",              "hard"),
    ("GDS XOR diffs",              "design__xor_difference__count",         "hard"),
    ("Illegal overlaps",           "magic__illegal_overlap__count",         "hard"),
    ("Setup violations",           "timing__setup_vio__count",              "hard"),
    ("Hold violations",            "timing__hold_vio__count",               "hard"),
    ("PDN violations",             "design__power_grid_violation__count",   "hard"),
    ("Critical disconnected pins", "design__critical_disconnected_pin__count", "hard"),
    ("Unmapped instances",         "design__instance_unmapped__count",      "hard"),
    ("Inferred latches",           "design__inferred_latch__count",         "hard"),
    ("Lint errors",                "design__lint_error__count",             "hard"),
    ("Flow errors",                "flow__errors__count",                   "hard"),
    ("Antenna violations",         "route__antenna_violation__count",       "soft"),
    ("Max slew violations",        "design__max_slew_violation__count",     "soft"),
    ("Max cap violations",         "design__max_cap_violation__count",      "soft"),
    ("Max fanout violations",      "design__max_fanout_violation__count",   "soft"),
    ("Disconnected pins",          "design__disconnected_pin__count",       "soft"),
    ("Floating nets",              "timing__drv__floating__nets",           "soft"),
]


def section_signoff(console, Table, Text, m):
    console.rule("SIGNOFF")
    t = Table()
    t.add_column("Check")
    t.add_column("Count", justify="right")
    t.add_column("Status")
    hard_fails = []
    for label, key, sev in CHECKS:
        v = m.get(key)
        if v is None:
            t.add_row(label, "—", Text("n/a", style="dim"))
        elif v == 0:
            t.add_row(label, "0", Text("PASS", style="bold green"))
        else:
            style = "bold red" if sev == "hard" else "bold yellow"
            word = "FAIL" if sev == "hard" else "WARN"
            t.add_row(label, Text(str(v), style=style), Text(word, style=style))
            if sev == "hard":
                hard_fails.append(label)
    console.print(t)
    if hard_fails:
        console.print(Text(f"✗ NOT CLEAN: {', '.join(hard_fails)}", style="bold red"))
    else:
        console.print(Text("✓ all hard checks clean", style="bold green"))


def section_corners(console, Table, Text, m, title="TIMING PER CORNER"):
    console.rule(title)
    corners = sorted(
        {k.split("__corner:")[1] for k in m if "__corner:" in k and k.startswith("timing")},
        key=corner_sort_key,
    )
    if not corners:
        console.print("no per-corner timing metrics")
        return

    def cell(key, corner, count=False):
        v = m.get(f"{key}__corner:{corner}")
        if v is None:
            return Text("—", style="dim")
        bad = (v > 0) if count else (v < 0)
        s = str(v) if count else f"{v:.3f}"
        return Text(s, style="red" if bad else "green")

    t = Table()
    t.add_column("Corner", no_wrap=True)
    for h in ("Setup WS", "Setup TNS", "#Setup", "Hold WS", "Hold TNS", "#Hold", "#Slew", "#Cap"):
        t.add_column(h, justify="right")
    for c in corners:
        t.add_row(
            c,
            cell("timing__setup__ws", c),
            cell("timing__setup__tns", c),
            cell("timing__setup_vio__count", c, count=True),
            cell("timing__hold__ws", c),
            cell("timing__hold__tns", c),
            cell("timing__hold_vio__count", c, count=True),
            cell("design__max_slew_violation__count", c, count=True),
            cell("design__max_cap_violation__count", c, count=True),
        )
    console.print(t)
    console.print(
        f"overall: setup WS {fnum(m.get('timing__setup__ws'))}  "
        f"TNS {fnum(m.get('timing__setup__tns'))}   |   "
        f"hold WS {fnum(m.get('timing__hold__ws'))}  "
        f"TNS {fnum(m.get('timing__hold__tns'))}"
    )


def _strip_common(stems):
    """Drop the shared prefix of lib stems so only the PVT part remains."""
    if len(stems) < 2:
        return dict(zip(stems, stems))
    pfx = commonprefix(stems)
    if len(pfx) < 4:
        pfx = ""
    return {s: s[len(pfx):] or s for s in stems}


def section_timing_models(console, Table, Text, stages):
    """Which liberty/RC models back each corner, and which STA stages ran it."""
    cfg_f = stages[-1].dir / "config.json" if stages else None
    if cfg_f is None or not cfg_f.is_file():
        return
    try:
        cfg = json.loads(cfg_f.read_text())
    except (json.JSONDecodeError, OSError):
        return
    corners = cfg.get("STA_CORNERS") or []
    if not corners:
        return
    libmap = cfg.get("LIB") or {}
    macmap = {}
    for mc in (cfg.get("MACROS") or {}).values():
        for pat, paths in (mc.get("lib") or {}).items():
            macmap.setdefault(pat, []).extend(paths)
    std_stems = sorted({Path(p).stem for ps in libmap.values() for p in ps})
    mac_stems = sorted({Path(p).stem for ps in macmap.values() for p in ps})
    std_short = _strip_common(std_stems)
    mac_short = _strip_common(mac_stems)
    default = cfg.get("DEFAULT_CORNER")

    console.rule("TIMING MODELS")
    t = Table()
    t.add_column("Corner", no_wrap=True)
    t.add_column("RC")
    t.add_column("Std-cell lib")
    t.add_column("Macro lib")
    t.add_column("STA stages")
    for c in sorted(corners, key=corner_sort_key):
        std = [std_short[Path(p).stem] for pat, ps in libmap.items()
               if fnmatch.fnmatch(c, pat) for p in ps]
        mac = [mac_short[Path(p).stem] for pat, ps in macmap.items()
               if fnmatch.fnmatch(c, pat) for p in ps]
        present = [s for s in stages if (s.dir / c).is_dir()]
        if len(present) == len(stages):
            ran = Text("all", style="green")
        elif not present:
            ran = Text("—", style="dim")
        else:
            missing = [s.label for s in stages if s not in present]
            ran = ("all except " + ", ".join(missing) if len(missing) <= 2
                   else ", ".join(s.label for s in present))
        t.add_row(c + (" *" if c == default else ""), c.split("_")[0],
                  ", ".join(std) or "—", ", ".join(mac) or "—", ran)
    console.print(t)
    base = []
    if std_stems:
        base.append(f"std cells: {commonprefix(std_stems).rstrip('_')}*")
    if mac_stems:
        base.append(f"macros: {commonprefix(mac_stems).rstrip('_')}*")
    console.print("  ".join(base)
                  + "   |   RC = interconnect extraction (tech LEF), * = default corner")


def section_evolution(console, Table, Text, stages):
    """Worst setup slack per PVT at every STA stage of the flow."""
    if len(stages) < 2:
        return
    pvts = []
    for s in stages:
        for k in s.metrics:
            if k.startswith("timing__setup__ws__corner:"):
                parts = k.split("__corner:")[1].split("_")
                if len(parts) > 1 and parts[1] not in pvts:
                    pvts.append(parts[1])
    if not pvts:
        return
    pvts.sort(key=lambda p: {"tt": 0, "ss": 1, "ff": 2}.get(p, 9))

    console.rule("TIMING EVOLUTION")
    t = Table()
    t.add_column("Stage", no_wrap=True)
    for p in pvts:
        t.add_column(f"{p} setup WS", justify="right")
    for h in ("Setup TNS", "#Setup", "Hold WS", "#Hold"):
        t.add_column(h, justify="right")

    def cell(v, count=False):
        if v is None:
            return Text("—", style="dim")
        bad = (v > 0) if count else (v < 0)
        s = str(v) if count else f"{v:.3f}"
        return Text(s, style="red" if bad else "green")

    for s in stages:
        m = s.metrics
        ran = stage_ran_corners(s)
        row = [f"{s.num:02d} {s.label}"]
        for p in pvts:
            row.append(cell(pvt_worst(m, "setup", p, ran)))
        row.append(cell(m.get("timing__setup__tns")))
        row.append(cell(m.get("timing__setup_vio__count"), count=True))
        row.append(cell(m.get("timing__hold__ws")))
        row.append(cell(m.get("timing__hold_vio__count"), count=True))
        t.add_row(*row)
    console.print(t)
    console.print("per-PVT WS = worst across that PVT's RC corners; "
                  "— = corner not run at that stage "
                  "(mid-pnr STA runs the default corner only)")


def section_postsynth(console, Table, Text, stages):
    """Post-synth STA: per-corner summary, worst path per corner, overlap."""
    st = next((s for s in stages if s.label == "post-synth"), None)
    if st is None:
        return
    if st.metrics:
        section_corners(console, Table, Text, st.metrics,
                        title=f"POST-SYNTH TIMING ({st.dir.name})")
    corners = stage_corners(st)
    if not corners:
        return
    t = Table(title="worst setup path per corner")
    t.add_column("Corner", no_wrap=True)
    t.add_column("Startpoint")
    t.add_column("Endpoint")
    t.add_column("Slack", justify="right")
    t.add_column("#Vio", justify="right")
    for c in corners:
        wp = parse_worst_path(st.dir / c, which="max")
        nv = st.metrics.get(f"timing__setup_vio__count__corner:{c}")
        if wp is None:
            t.add_row(c, "—", "—", Text("—", style="dim"), fnum(nv))
            continue
        style = "red" if wp["verdict"] == "VIOLATED" else "green"
        t.add_row(c, wp["start"], wp["end"],
                  Text(fnum(wp["slack"]), style=style), fnum(nv))
    console.print(t)
    # which endpoints fail in several corners (structural) vs one (marginal)
    sets = {c: {e for _s, e, _sl in parse_violators(st.dir / c)["setup"]}
            for c in corners}
    viol = {c: s for c, s in sets.items() if s}
    if len(viol) >= 2:
        union = set().union(*viol.values())
        common = set.intersection(*viol.values())
        per = ", ".join(f"{c} {len(s)}" for c, s in sorted(viol.items(),
                                                           key=lambda cs: corner_sort_key(cs[0])))
        console.print(f"violating endpoints: {per}   |   union {len(union)}, "
                      f"failing in every violating corner {len(common)}")


def section_paths(console, Table, Text, m, stage, n, corner_override):
    label = stage.label if stage else ""
    # Text() so rich doesn't eat the [stage] part as markup
    console.rule(Text(f"WORST PATHS [{label}]") if label else "WORST PATHS")
    if stage is None:
        console.print("no *-openroad-sta* step in this run")
        return
    for kind, rpt in (("setup", "max"), ("hold", "min")):
        corner = corner_override or stage_worst_corner(stage, m, kind)
        cdir = resolve_corner_dir(stage, corner) if corner else None
        if cdir is None:
            continue
        viols = parse_violators(cdir)[kind]
        vio_count = m.get(f"timing__{kind}_vio__count") or 0
        if not viols and vio_count == 0:
            console.print(Text(f"{kind}: clean ({corner})", style="green"))
            continue
        console.print(Text(f"{kind} @ {corner}  ({len(viols)} violating paths)",
                           style="bold red"))
        t = Table()
        t.add_column("Startpoint")
        t.add_column("Endpoint")
        t.add_column("Slack", justify="right")
        for start, end, slack in viols[:n]:
            t.add_row(start, end, Text(f"{slack:.4f}", style="red"))
        console.print(t)
        by_start = Counter(s.split("/")[0] for s, _e, _sl in viols)
        top = ", ".join(f"{c}× {s}" for s, c in by_start.most_common(5))
        console.print(f"startpoints by violation count: {top}")
        wp = parse_worst_path(cdir, which=rpt)
        if wp and wp["nets"]:
            console.print(
                f"worst path {wp['start']} → {wp['end']} "
                f"(slack {fnum(wp['slack'])}, {wp['verdict']}) goes through:"
            )
            for net in wp["nets"][:8]:
                console.print(f"  · {net}")
        console.print()


def section_slack_hist(console, Table, Text, m, stage, corner_override):
    """Violated-path slack distribution, 1 ns buckets (truncated like awk '%d')."""
    if stage is None:
        return
    for kind, rpt in (("setup", "max"), ("hold", "min")):
        corner = corner_override or stage_worst_corner(stage, m, kind)
        cdir = resolve_corner_dir(stage, corner) if corner else None
        if cdir is None:
            continue
        slacks = parse_violated_slacks(cdir, which=rpt)
        if not slacks:
            continue
        console.rule(Text(f"SLACK HISTOGRAM ({kind} @ {corner}) [{stage.label}]"))
        buckets = Counter(int(s) for s in slacks)  # trunc toward zero: -6.62 -> -6
        peak = max(buckets.values())
        width = 46
        for b in sorted(buckets):
            n = buckets[b]
            bar = "█" * max(1, round(n / peak * width))
            console.print(Text(f"{b:>6} │ {n:>5}  ") + Text(bar, style="red"))
        console.print(f"       {len(slacks)} violated paths, worst {min(slacks):.4f} ns")


def section_stats(console, Table, Text, m, run_dir):
    console.rule("DESIGN STATS")
    t = Table()
    t.add_column("Metric")
    t.add_column("Value", justify="right")
    util = m.get("design__instance__utilization")
    if util is not None and util <= 1:
        util *= 100
    wirelength = m.get("route__wirelength", m.get("global_route__wirelength"))
    vias = m.get("route__vias", m.get("global_route__vias"))
    rows = [
        ("Die area", fmt_area(m.get("design__die__area"))),
        ("Core area", fmt_area(m.get("design__core__area"))),
        ("Utilization", f"{util:.1f} %" if util is not None else "—"),
        ("Instances", f"{m.get('design__instance__count'):,}"
         if m.get("design__instance__count") is not None else "—"),
        ("  sequential", fnum(m.get("design__instance__count__class:sequential_cell"))),
        ("  combinational", fnum(m.get("design__instance__count__class:multi_input_combinational_cell"))),
        ("  buffers (timing repair)", fnum(m.get("design__instance__count__class:timing_repair_buffer"))),
        ("  clock buffers", fnum(m.get("design__instance__count__class:clock_buffer"))),
        ("  macros", fnum(m.get("design__instance__count__class:macro"))),
        ("  antenna diodes", fnum(m.get("antenna_diodes_count"))),
        ("Power total", fmt_power(m.get("power__total"))),
        ("  internal", fmt_power(m.get("power__internal__total"))),
        ("  switching", fmt_power(m.get("power__switching__total"))),
        ("  leakage", fmt_power(m.get("power__leakage__total"))),
        ("Wirelength", f"{wirelength:,.0f} µm" if wirelength is not None else "—"),
        ("Vias", f"{vias:,}" if vias is not None else "—"),
        ("IR drop worst / avg", f"{fmt_volts(m.get('ir__drop__worst'))} / "
                                f"{fmt_volts(m.get('ir__drop__avg'))}"),
        ("Clock skew setup / hold", f"{fnum(m.get('clock__skew__worst_setup'))} / "
                                    f"{fnum(m.get('clock__skew__worst_hold'))} ns"),
    ]
    for label, val in rows:
        t.add_row(label, val)
    console.print(t)
    gds = list((run_dir / "final" / "gds").glob("*.gds"))
    if gds:
        console.print(f"GDS: {gds[0]}")


def section_warnings(console, Table, Text, m):
    codes = sorted(
        ((k.split(":", 1)[1], v) for k, v in m.items()
         if k.startswith("flow__warnings__count:")),
        key=lambda kv: -kv[1],
    )
    if not codes:
        return
    console.rule(f"FLOW WARNINGS ({sum(v for _c, v in codes)})")
    t = Table()
    t.add_column("Code")
    t.add_column("Count", justify="right")
    for code, count in codes[:12]:
        t.add_row(code, str(count))
    console.print(t)


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("run", nargs="?", help="run name under runs/ or a path (default: latest)")
    ap.add_argument("--paths", type=int, default=8, metavar="N",
                    help="violating paths to list per check (default 8)")
    ap.add_argument("--corner", help="force STA corner for the paths section")
    ap.add_argument("--stage", metavar="S",
                    help="STA stage for paths/histogram: label ('post-synth', "
                         "'mid-pnr-2'), substring ('synth'), or step number "
                         "(default: last stage, i.e. post-pnr)")
    ap.add_argument("--plain", action="store_true", help="plain text, no rich/color")
    ap.add_argument("--runs-dir", default="runs", type=Path, help="runs directory (default runs/)")
    args = ap.parse_args()

    console, Table, Text = _load_ui(args.plain)
    run_dir = resolve_run(args.run, args.runs_dir)
    metrics, source = load_metrics(run_dir)

    # header: design/clock from resolved.json if present
    design = clock = None
    resolved = run_dir / "resolved.json"
    if resolved.is_file():
        try:
            cfg = json.loads(resolved.read_text())
            design, clock = cfg.get("DESIGN_NAME"), cfg.get("CLOCK_PERIOD")
        except (json.JSONDecodeError, OSError):
            pass
    console.rule(f"RUN {run_dir.name}")
    hdr = []
    if design:
        hdr.append(f"design {design}")
    if clock:
        hdr.append(f"clock {clock} ns")
    hdr.append(f"metrics from {source}")
    if source != "final":
        hdr.append("RUN INCOMPLETE")
    console.print(Text("  |  ".join(hdr),
                       style="bold yellow" if source != "final" else ""))
    err_log = run_dir / "error.log"
    if err_log.is_file() and err_log.stat().st_size > 0:
        n_err = len(err_log.read_text().splitlines())
        console.print(Text(f"error.log: {n_err} lines — check {err_log}", style="bold red"))

    stages = find_sta_stages(run_dir)
    stage = pick_stage(stages, args.stage)

    section_signoff(console, Table, Text, metrics)
    section_timing_models(console, Table, Text, stages)
    section_corners(console, Table, Text, metrics, title="TIMING PER CORNER (final)")
    section_evolution(console, Table, Text, stages)
    section_postsynth(console, Table, Text, stages)
    sm = (stage.metrics or metrics) if stage else metrics
    section_paths(console, Table, Text, sm, stage, args.paths, args.corner)
    section_slack_hist(console, Table, Text, sm, stage, args.corner)
    section_stats(console, Table, Text, metrics, run_dir)
    section_warnings(console, Table, Text, metrics)


if __name__ == "__main__":
    main()
