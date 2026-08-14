import os
from librelane.flows.flow import Flow
from steps import CellResize

PROJECT = os.path.dirname(os.path.abspath(__file__))
RUN_NAME = "Slew-Fix"
PDK = "sky130A"
SCL = "sky130_fd_sc_hd"

Classic = Flow.factory.get("Classic")
steps = list(Classic.Steps)
steps.insert(35, CellResize) # custom resize immediately post CTS

class CustomFlow(Classic):
	Steps = steps

if __name__ == "__main__":
	flow = CustomFlow(
		config=os.path.join(PROJECT, "config.json"),
		pdk=PDK, scl=SCL,
		pdk_root=os.environ["PDK_ROOT"],
		design_dir=PROJECT,
	)
	flow.start(tag=RUN_NAME)