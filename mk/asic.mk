# synthesis sanity + LibreLane physical flow
# Requires common.mk. Assumes config.yaml in project root for gds.

LL_CONFIG   ?= config.yaml
PDK_ROOT    ?= $(HOME)/eda/.volare
LL_NIX      ?= $(HOME)/eda/librelane/shell.nix

.PHONY: sv2v synth synth-report gds summary drc-view

# sv2v
sv2v: | $(BUILD)
	@mkdir -p synth
	$(SV2V) $(addprefix -I,$(INC_DIRS)) $(SRCS) > synth/$(TOP).v
	@echo "wrote synth/$(TOP).v"

# yosys generic synth check
synth: sv2v
	$(YOSYS) -p "read_verilog synth/$(TOP).v; \
		hierarchy -top $(TOP); \
		proc; opt; fsm; opt; memory; opt; \
		check -assert; \
		synth -top $(TOP); \
		tee -o synth/$(TOP).stat.rpt stat; \
		write_json synth/$(TOP).json"
	@grep -q '\$$dlatch' synth/$(TOP).json && \
		{ echo "!! LATCH INFERRED - fix incomplete if/case"; exit 1; } || \
		echo "no latches inferred"

synth-report:
	@cat synth/$(TOP).stat.rpt

# LibreLane full flow
gds:
	nix-shell $(LL_NIX) --run \
		"librelane --pdk-root '$(PDK_ROOT)' '$(LL_CONFIG)'"

# resume from a specific step of the last run, e.g. make gds-from FROM=OpenROAD.Floorplan
gds-from:
	nix-shell $(LL_NIX) --run \
		"librelane --pdk-root '$(PDK_ROOT)' --last-run --from $(FROM) '$(LL_CONFIG)'"

summary:
	@run=$$(ls -td runs/*/ 2>/dev/null | head -1); \
	[ -n "$$run" ] || { echo "no runs/"; exit 1; }; \
	echo "== $$run =="; \
	if [ -f "$$run/final/metrics.json" ]; then \
		python3 -c "import json; m=json.load(open('$$run/final/metrics.json')); \
		[print(f'{k:60s} {v}') for k,v in sorted(m.items()) \
		 if any(s in k.lower() for s in ('slack','area','drc','lvs','util','power','tns','wns'))]"; \
	else find "$$run" -name '*summary*' -print; fi

drc-view:
	@gds=$$(ls -t runs/*/final/gds/*.gds 2>/dev/null | head -1); \
	if [ -n "$$gds" ]; then klayout "$$gds" & else echo "no GDS under runs/"; fi
