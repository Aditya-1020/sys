import argparse
import os
import re
import shutil
import sys
from librelane.common.misc import slugify
from librelane.flows.flow import Flow

PROJECT = os.path.dirname(os.path.abspath(__file__))
RUN_DIR = os.path.join(PROJECT, "runs", "Final")
RUN_NAME = "Fanout-fix"
PDK = "sky130A"
SCL = "sky130_fd_sc_hd"

Classic = Flow.factory.get("Classic")

class CustomFlow(Classic):
	pass

_STEP_DIR = re.compile(r"^(\d+)-(.+)$")

def resolve_step_id(name: str) -> str:
	needle = name.lower()
	by_id = {cls.id.lower(): cls.id for cls in CustomFlow.Steps}
	if needle in by_id:
		return by_id[needle]

	slug = slugify(name)
	by_slug = {slugify(cls.id): cls.id for cls in CustomFlow.Steps}
	if slug in by_slug:
		return by_slug[slug]

	matches = [cls.id for cls in CustomFlow.Steps if needle in slugify(cls.id)]
	if len(matches) == 1:
		return matches[0]
	if len(matches) > 1:
		print(f"Ambiguous step {name!r}: {', '.join(matches)}", file=sys.stderr)
		sys.exit(1)
	print(f"Unknown step {name!r}", file=sys.stderr)
	sys.exit(1)


def rerun_from(step_id: str) -> None:
	slug = slugify(resolve_step_id(step_id))
	ordinals = []
	for entry in os.listdir(RUN_DIR):
		match = _STEP_DIR.match(entry)
		if match and match.group(2) == slug:
			ordinals.append(int(match.group(1)))
	if not ordinals:
		print(f"No prior run of {step_id!r} in {RUN_DIR}", file=sys.stderr)
		sys.exit(1)

	cutoff = min(ordinals)
	removed = []
	for entry in sorted(os.listdir(RUN_DIR)):
		match = _STEP_DIR.match(entry)
		if not match or int(match.group(1)) < cutoff:
			continue
		path = os.path.join(RUN_DIR, entry)
		if os.path.isdir(path):
			shutil.rmtree(path)
			removed.append(entry)

	print(f"Removed {len(removed)} step(s) from ordinal {cutoff}:")
	for entry in removed:
		print(f"  {entry}")


def main() -> None:
	parser = argparse.ArgumentParser(description="Run the custom LibreLane flow.")
	parser.add_argument(
		"--rerun-from",
		metavar="STEP",
		help="drop this step and all later steps, then resume Final",
	)
	parser.add_argument("-F", "--from", dest="frm", metavar="STEP")
	parser.add_argument("-T", "--to", metavar="STEP")
	args = parser.parse_args()

	if args.rerun_from:
		rerun_from(args.rerun_from)

	flow = CustomFlow(
		config=os.path.join(PROJECT, "config.json"),
		pdk=PDK,
		scl=SCL,
		pdk_root=os.environ["PDK_ROOT"],
		design_dir=PROJECT,
	)
	kwargs = {k: v for k, v in {"frm": args.frm, "to": args.to}.items() if v}
	flow.start(tag=RUN_NAME, **kwargs)


if __name__ == "__main__":
	main()
