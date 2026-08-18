import glob
import json
import os
import re
from collections import Counter
from librelane.config.variable import Variable
from librelane.logging.logger import console, rule
from librelane.state.design_format import DesignFormat
from librelane.steps import OpenROAD
from librelane.steps.step import Step
from rich.table import Table

_PROJECT = os.path.dirname(os.path.abspath(__file__))

_CONN = re.compile(r"\.\w+\(\s*([^)]*?)\s*\)")
_CONST = re.compile(r"^\d*'[bdho]?[0-9a-fxzA-FXZ_]+$")


def _fanout(netlist): # load count per net
    with open(netlist, encoding="utf8") as f:
        uses = Counter(n for n in _CONN.findall(f.read()) if n and not _CONST.match(n))
    return Counter({net: n - 1 for net, n in uses.items() if n > 1})


@Step.factory.register()
class SynthFanoutCheck(Step): # report high fanout nets in synthesis nl
    id = "Custom.SynthFanoutCheck"
    name = "Synthesis Fanout Check"
    long_name = "Post-Synthesis Fanout Check"

    inputs = [DesignFormat.NETLIST]
    outputs = []

    config_vars = [
        Variable(
            "FANOUT_CHECK_LIMIT",
            int,
            "Nets with more loads than this are reported. 128 flags the worst"
            " handful on a healthy netlist; a collapsed reset tree lands in the"
            " thousands.",
            default=128,
        ),
        Variable("FANOUT_CHECK_TOP_N", int, "How many of the worst nets to list.", default=10),
    ]

    def run(self, state_in, **kwargs):
        limit = self.config["FANOUT_CHECK_LIMIT"]
        fanout = _fanout(str(state_in[DesignFormat.NETLIST]))

        # clocks fan out to everything until CTS builds the tree
        clock = self.config["CLOCK_PORT"]
        for net in [clock] if isinstance(clock, str) else clock or []:
            fanout.pop(net, None)

        if not fanout:
            self.warn("no nets found in netlist; skipping fanout check")
            return {}, {}

        worst = fanout.most_common(self.config["FANOUT_CHECK_TOP_N"])
        over = sum(1 for n in fanout.values() if n > limit)

        with open(os.path.join(self.step_dir, "fanout.rpt"), "w", encoding="utf8") as f:
            f.writelines(f"{n}\t{net}\n" for net, n in fanout.most_common())

        table = Table(title=f"Highest-fanout nets (limit {limit})", title_justify="left")
        table.add_column("Fanout", justify="right")
        table.add_column("Net")
        for net, n in worst:
            table.add_row(str(n), net, style="red" if n > limit else None)
        console.print(table)

        if over:
            self.warn(f"{over} net(s) exceed a fanout of {limit}; " f"worst is {worst[0][0]} with {worst[0][1]} loads")

        return {}, {
            "synthesis__max_fanout": worst[0][1],
            "synthesis__high_fanout_net__count": over,
        }


@Step.factory.register()
class CTS(OpenROAD.CTS):
    id = "Custom.CTS"
    name = "Clock Tree Synthesis"
    long_name = "Clock Tree Synthesis (local script)"

    config_vars = OpenROAD.CTS.config_vars + [
        Variable(
            "CTS_NO_INSERTION_DELAY",
            bool,
            "stop CTS balacing the macro tree against register tree"
            "avoid buffering with macro tree",
            default=False,
        ),
        Variable(
            "CTS_DONT_USE_DUMMY_LOAD",
            bool,
            "stop CTS inserting capacitive ballast cells to equalise latency",
            default=False,
        ),
    ]

    def get_script_path(self):
        return os.path.join(_PROJECT, "scripts", "openroad", "cts.tcl")


_CHECKS = [
    ("design__max_slew_violation__count", "Max slew"),
    ("design__max_cap_violation__count", "Max cap"),
    ("design__max_fanout_violation__count", "Max fanout"),
    ("timing__setup_vio__count", "Setup"),
    ("timing__hold_vio__count", "Hold"),
    ("magic__drc_error__count", "Magic DRC"),
    ("klayout__drc_error__count", "KLayout DRC"),
    ("route__drc_errors", "Routing DRC"),
    ("design__lvs_error__count", "LVS"),
    ("design__xor_difference__count", "GDS XOR"),
    ("antenna__violating__nets", "Antenna nets"),
]

_WS = "timing__setup__ws__corner:"

@Step.factory.register()
class FlowSummary(Step):
    id = "Custom.FlowSummary"
    name = "Flow Summary"
    long_name = "Flow Summary Report"

    inputs = []
    outputs = []

    @staticmethod
    def _slacks(step_dir): # single step worst slack
        own = os.path.join(step_dir, "or_metrics_out.json")
        state = os.path.join(step_dir, "state_out.json")
        if os.path.exists(own):
            with open(own, encoding="utf8") as f:
                metrics, ran = json.load(f), None
        elif os.path.exists(state):
            with open(state, encoding="utf8") as f:
                metrics = json.load(f).get("metrics", {})
            # state_out carries every corner so far, keep the ones this step ran
            ran = {e.name for e in os.scandir(step_dir) if e.is_dir()}
        else:
            return {}
        return {k[len(_WS):]: v for k, v in metrics.items()
                if k.startswith(_WS) and (ran is None or k[len(_WS):] in ran)}

    @property
    def _run_dir(self):
        return os.path.dirname(self.step_dir)

    def _stages(self):
        dirs = sorted(glob.glob(os.path.join(self._run_dir, "*-openroad-sta*")),
                      key=lambda d: int(os.path.basename(d).split("-", 1)[0]))
        return [(os.path.basename(d), s) for d in dirs if (s := self._slacks(d))]

    def _fanout_report(self):
        hits = glob.glob(os.path.join(self._run_dir, "*-custom-synthfanoutcheck", "fanout.rpt"))
        return hits[0] if hits else None

    def run(self, state_in, **kwargs):
        m = state_in.metrics
        rule("Flow Summary")

        checks = Table(title="Signoff", title_justify="left")
        checks.add_column("Check")
        checks.add_column("Count", justify="right")
        for key, label in _CHECKS:
            v = m.get(key)
            if v is None:
                checks.add_row(label, "n/a", style="dim")
            else:
                checks.add_row(label, str(v), style="red" if v else "green")
        console.print(checks)

        stages = self._stages()
        if stages:
            corners = sorted({c for _, s in stages for c in s})
            evo = Table(title="Setup WS by stage (ns)", title_justify="left")
            evo.add_column("Stage")
            for corner in corners:
                evo.add_column(corner, justify="right")
            for name, slacks in stages:
                evo.add_row(name, *(f"{slacks[c]:+.3f}" if c in slacks else "-" for c in corners))
            console.print(evo)

        max_fanout = m.get("synthesis__max_fanout")
        if max_fanout is not None:
            over = m.get("synthesis__high_fanout_net__count", 0)
            console.print(f"\nSynthesis fanout: worst net has [bold]{max_fanout}[/bold] "
                          f"loads, {over} net(s) over limit.")
            report = self._fanout_report()
            if report and over:
                with open(report, encoding="utf8") as f:
                    for line in list(f)[:5]:
                        loads, net = line.rstrip("\n").split("\t", 1)
                        console.print(f"  {loads:>6}  {net}")

        return {}, {}
