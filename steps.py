from pathlib import Path
from librelane.steps.openroad import OpenROADStep

class CellResize(OpenROADStep):
	id = "OpenROAD.CellResize"
	def get_script_path(self):
		return str(Path(__file__).with_name("resize.tcl"))