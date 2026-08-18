import json
import os
import re
from collections import Counter

import altair as alt
import pandas as pd

alt.data_transformers.disable_max_rows()

CORNER = "max_ss_100C_1v60"
OUT = "assets/plots"

RUNS = {
	"100MHz": dict(
		metrics="runs/Fanout-fix/final/metrics.json",
		sta="runs/Fanout-fix/57-openroad-stapostpnr",
		nl="runs/Fanout-fix/final/nl/top.nl.v",
		period=10.0),
	"eco2": dict(
		metrics="runs/eco2/final/metrics.json",
		sta="runs/eco2/59-openroad-stapostpnr",
		nl="runs/eco2/final/nl/top.nl.v",
		period=5.0),
}
LABELS = list(RUNS)

for r in RUNS.values():
	d = json.load(open(r["metrics"]))
	r["m"] = d.get("metrics", d)


def get(run, key):
	return RUNS[run]["m"].get(key)


def at_corner(run, key):
	return get(run, f"{key}__corner:{CORNER}")


def klass(run, name):
	return get(run, f"design__instance__count__class:{name}")


def fmax(run):
	ws = at_corner(run, "timing__setup__ws")
	return None if ws is None else 1000.0 / (RUNS[run]["period"] - ws)


METRICS = {
	"timing": {
		"clock period (ns)": lambda r: RUNS[r]["period"],
		"fmax (MHz)": fmax,
		"setup WS (ns)": lambda r: at_corner(r, "timing__setup__ws"),
		"hold WS (ns)": lambda r: at_corner(r, "timing__hold__ws"),
		"setup violations": lambda r: at_corner(r, "timing__setup_vio__count"),
		"hold violations": lambda r: at_corner(r, "timing__hold_vio__count"),
		"clock skew (ns)": lambda r: at_corner(r, "clock__skew__worst_setup"),
		"max slew violations": lambda r: get(r, "design__max_slew_violation__count"),
		"max cap violations": lambda r: get(r, "design__max_cap_violation__count"),
	},
	"area": {
		"die area (um2)": lambda r: get(r, "design__die__area"),
		"core area (um2)": lambda r: get(r, "design__core__area"),
		"utilization (%)": lambda r: 100 * get(r, "design__instance__utilization"),
		"std cells": lambda r: get(r, "design__instance__count__stdcell"),
		"std cell area (um2)": lambda r: get(r, "design__instance__area__stdcell"),
		"sequential": lambda r: klass(r, "sequential_cell"),
		"combinational": lambda r: klass(r, "multi_input_combinational_cell"),
		"inverters": lambda r: klass(r, "inverter"),
		"fill cells": lambda r: klass(r, "fill_cell"),
	},
	"buffers": {
		"buffers": lambda r: klass(r, "buffer"),
		"timing repair buffers": lambda r: klass(r, "timing_repair_buffer"),
		"setup buffers": lambda r: get(r, "design__instance__count__setup_buffer"),
		"hold buffers": lambda r: get(r, "design__instance__count__hold_buffer"),
		"clock buffers": lambda r: klass(r, "clock_buffer"),
		"clock inverters": lambda r: klass(r, "clock_inverter"),
		"clock gate cells": lambda r: klass(r, "clock_gate_cell"),
	},
	"power": {
		"total (W)": lambda r: get(r, "power__total"),
		"internal (W)": lambda r: get(r, "power__internal__total"),
		"switching (W)": lambda r: get(r, "power__switching__total"),
		"leakage (W)": lambda r: get(r, "power__leakage__total"),
	},
	"route": {
		"wirelength (um)": lambda r: get(r, "route__wirelength"),
		"longest net (um)": lambda r: get(r, "route__wirelength__max"),
		"nets": lambda r: get(r, "route__net"),
		"vias": lambda r: get(r, "route__vias"),
		"antenna diodes": lambda r: get(r, "antenna_diodes_count"),
		"unannotated nets": lambda r: get(r, "timing__unannotated_net__count"),
		"displacement (um)": lambda r: get(r, "design__instance__displacement__total"),
		"IR drop worst (V)": lambda r: get(r, "ir__drop__worst"),
		"magic DRC": lambda r: get(r, "magic__drc_error__count"),
		"LVS errors": lambda r: get(r, "design__lvs_error__count"),
		"XOR diffs": lambda r: get(r, "design__xor_difference__count"),
	},
	"fanout": {
		"max fanout (pre-PnR)": lambda r: get(r, "synthesis__max_fanout"),
		"high fanout nets": lambda r: get(r, "synthesis__high_fanout_net__count"),
		"fanout violations": lambda r: get(r, "design__max_fanout_violation__count"),
	},
}


def metrics_frame():
	rows = []
	for group, items in METRICS.items():
		for name, fn in items.items():
			for run in LABELS:
				rows.append(dict(group=group, metric=name, run=run, value=fn(run)))
	return pd.DataFrame(rows)


def paths_frame():
	rows = []
	for run in LABELS:
		for kind, check in (("max", "setup"), ("min", "hold")):
			f = os.path.join(RUNS[run]["sta"], CORNER, f"{kind}.rpt")
			if not os.path.exists(f):
				continue
			for blk in open(f, errors="replace").read().split("Startpoint: ")[1:]:
				ep = re.search(r"Endpoint: (\S+)", blk)
				sl = re.search(r"([-\d.]+)\s+slack", blk)
				if ep and sl:
					rows.append(dict(run=run, check=check, start=blk.split(None, 1)[0],
									 endpoint=ep.group(1), slack=float(sl.group(1))))
	return pd.DataFrame(rows)


def drive_frame():
	pat = re.compile(r"sky130_fd_sc_hd__(clk)?(buf|inv)_(\d+)")
	rows = []
	for run in LABELS:
		counts = Counter()
		for clk, kind, size in pat.findall(open(RUNS[run]["nl"], errors="replace").read()):
			counts[(("clock " if clk else "data ") + kind, int(size))] += 1
		for (kind, size), n in counts.items():
			rows.append(dict(run=run, kind=kind, size=size, count=n))
	return pd.DataFrame(rows)


def drc_frame():
	rows = []
	for run in LABELS:
		for k, v in RUNS[run]["m"].items():
			if k.startswith("route__drc_errors__iter:"):
				rows.append(dict(run=run, iteration=int(k.split(":")[1]), errors=v))
	return pd.DataFrame(rows).sort_values(["run", "iteration"])


def eco_path_frame(start="_36852_"):
	stage = re.compile(
		r"^\s*(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+[\^v]\s+(\S+)\s+\((\S+)\)")
	rows = []
	for run in LABELS:
		f = os.path.join(RUNS[run]["sta"], CORNER, "max.rpt")
		if not os.path.exists(f):
			continue
		for blk in open(f, errors="replace").read().split("Startpoint: ")[1:]:
			if not blk.startswith(start):
				continue
			launched = False
			for i, line in enumerate(blk.split("data arrival time")[0].splitlines()):
				g = stage.match(line)
				if not g:
					continue
				fo, cap, slew, delay, _, pin, cell = g.groups()
				launched = launched or pin.startswith(start)
				if launched:
					rows.append(dict(run=run, order=len(rows), pin=pin,
									 cell=cell.replace("sky130_fd_sc_hd__", ""),
									 fanout=int(fo), cap=float(cap),
									 slew=float(slew), delay=float(delay)))
			break
	return pd.DataFrame(rows)


COLOR = alt.Scale(domain=LABELS, range=["#8d99ae", "#00798c"])
RUN = alt.Color("run:N", scale=COLOR, sort=LABELS, title=None)
RUNX = alt.X("run:N", sort=LABELS, title=None, axis=alt.Axis(labelAngle=0))


def save(chart, name):
	chart.save(os.path.join(OUT, name))
	print("  wrote", os.path.join(OUT, name))


def chart_headline(mf):
	keep = ["fmax (MHz)", "setup WS (ns)", "hold WS (ns)", "clock skew (ns)", "utilization (%)", "total (W)"]
	d = mf[mf.metric.isin(keep)].dropna(subset=["value"])
	bars = alt.Chart(d).mark_bar().encode(
		x=RUNX, y=alt.Y("value:Q", title=None), color=RUN,
		tooltip=["run", "metric", "value"])
	text = alt.Chart(d).mark_text(dy=-6, fontSize=10).encode(
		x=RUNX, y="value:Q", text=alt.Text("value:Q", format=".4g"))
	return (bars + text).properties(width=140, height=150).facet(
		facet=alt.Facet("metric:N", title=None, sort=keep), columns=3
	).resolve_scale(y="independent").properties(title="Headline metrics")


def chart_violations(mf):
	keep = ["setup violations", "hold violations", "max slew violations", "max cap violations"]
	d = mf[mf.metric.isin(keep)].dropna(subset=["value"])
	return alt.Chart(d).mark_bar().encode(
		x=RUNX,
		y=alt.Y("value:Q", title="violations", stack=True),
		color=alt.Color("metric:N", title=None, scale=alt.Scale(scheme="tableau10")),
		tooltip=["run", "metric", "value"],
	).properties(width=220, height=260, title=f"Violations at {CORNER}")


def chart_stack(mf, group, keep, title, ytitle, normalize=False):
	d = mf[(mf.group == group) & mf.metric.isin(keep)].dropna(subset=["value"])
	y = alt.Y("value:Q", title=ytitle, stack="normalize" if normalize else True)
	return alt.Chart(d).mark_bar().encode(
		x=RUNX, y=y,
		color=alt.Color("metric:N", title=None, sort=keep, scale=alt.Scale(scheme="tableau20")),
		order=alt.Order("metric:N"),
		tooltip=["run", "metric", "value"],
	).properties(width=220, height=260, title=title)


def chart_slack(pf, zoom=False):
	d = pf if not zoom else pf[pf.slack < 0.8]
	bars = alt.Chart().mark_bar().encode(
		x=alt.X("slack:Q", bin=alt.Bin(maxbins=70), title="slack (ns)"),
		y=alt.Y("count():Q", title="paths"),
		color=RUN, tooltip=["run", "count()"])
	rule = alt.Chart().mark_rule(color="black", strokeDash=[4, 3]).encode(
		x=alt.datum(0))
	return alt.layer(bars, rule, data=d).properties(
		width=330, height=130).facet(
		row=alt.Row("run:N", sort=LABELS, title=None),
		column=alt.Column("check:N", title=None),
	).resolve_scale(y="independent").properties(title=("Slack distribution, closure region" if zoom else "Slack distribution, all paths"))


def chart_drive(df):
	return alt.Chart(df).mark_bar().encode(
		x=alt.X("size:O", title="drive strength"),
		y=alt.Y("count:Q", title="cells"),
		xOffset=alt.XOffset("run:N", sort=LABELS),
		color=RUN, tooltip=["run", "kind", "size", "count"],
	).properties(width=260, height=200).facet(
		column=alt.Column("kind:N", title=None)
	).resolve_scale(y="independent").properties(
		title="Buffer / inverter drive strength")


def chart_drc(df):
	return alt.Chart(df).mark_line(point=True).encode(
		x=alt.X("iteration:O", title="detailed-routing iteration"),
		y=alt.Y("errors:Q", title="DRC errors", scale=alt.Scale(type="symlog")),
		color=RUN, tooltip=["run", "iteration", "errors"],
	).properties(width=420, height=260, title="Router convergence")


def chart_eco_path(df):
	return alt.Chart(df).mark_bar().encode(
		y=alt.Y("pin:N", sort=alt.SortField("order"), title=None),
		x=alt.X("delay:Q", title="stage delay (ns)"),
		color=RUN, row=alt.Row("run:N", sort=LABELS, title=None),
		tooltip=["run", "pin", "cell", "fanout", "cap", "slew", "delay"],
	).properties(width=420, height=260, title="Critical path from _36852_, stage delays")


def print_table(mf):
	t = mf.pivot_table(index=["group", "metric"], columns="run", values="value", sort=False)[LABELS]
	print(t.to_string(float_format=lambda v: f"{v:,.4g}", na_rep="-"))


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	mf, pf = metrics_frame(), paths_frame()
	print_table(mf)
	print()
	save(chart_headline(mf), "01_headline.html")
	save(chart_violations(mf), "02_violations.html")
	save(chart_stack(mf, "power", ["internal (W)", "switching (W)", "leakage (W)"], "Power breakdown", "W"), "03_power.html")
	save(chart_stack(mf, "area", ["sequential", "combinational", "inverters", "fill cells"], "Cell mix", "cells"), "04_cell_mix.html")
	save(chart_slack(pf), "05_slack.html")
	save(chart_slack(pf, zoom=True), "06_slack_zoom.html")
	save(chart_drive(drive_frame()), "07_drive_strength.html")
	save(chart_drc(drc_frame()), "08_drc.html")
	save(chart_eco_path(eco_path_frame()), "09_eco_path.html")
