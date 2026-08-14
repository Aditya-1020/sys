import os

from librelane.flows.flow import Flow

PROJECT = os.path.dirname(os.path.abspath(__file__))

PDK = "sky130A"
SCL = "sky130_fd_sc_hd"

Classic = Flow.factory.get("Classic")

wanted = {
    "Yosys.JsonHeader",
    "Yosys.Synthesis",
    "Checker.YosysUnmappedCells",
    "Checker.YosysSynthChecks",
    "Checker.NetlistAssignStatements",
    "OpenROAD.CheckSDCFiles",
    "OpenROAD.CheckMacroInstances",
    "OpenROAD.STAPrePNR",
}

steps = []

for step in Classic.Steps:
    if step.get_implementation_id() in wanted:
        steps.append(step)

print("Selected steps:")
for step in steps:
    print("  ", step.get_implementation_id())


class STAFlow(Classic):
    Steps = steps


if __name__ == "__main__":
    flow = STAFlow(
        config=os.path.join(PROJECT, "config_sta.json"),
        pdk=PDK,
        scl=SCL,
        pdk_root=os.environ["PDK_ROOT"],
        design_dir=PROJECT,
    )

    flow.start(tag="sta")