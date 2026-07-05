# mk/sta.mk — standalone gate-level STA on one module against the PDK.
# Requires common.mk + asic.mk (reuses sv2v). Uses OpenSTA (`sta`, in the
# OSS CAD Suite) and the PDK liberty files. This is PRE-LAYOUT STA:
#   real cell delays, ZERO interconnect delay (no SPEF/parasitics).
# It is a fast per-block Fmax sanity check, NOT signoff. Signoff numbers
# come from `make gds` (LibreLane runs multicorner STA with extracted RC).
#
# Convention (mirrors sim.mk): `make sta U=<mod>` reads constraints/<mod>.sdc.
#
#   make sta               STA on TOP        (setup, slow corner)
#   make sta U=pe          STA on module pe  (constraints/pe.sdc)
#   make sta CORNER=ff U=pe hold check at the fast corner
#   make sta-report        re-print the last report

U          ?= $(TOP)
PDK_ROOT   ?= $(HOME)/eda/.volare
PDK        ?= sky130A
STD_CELL   ?= sky130_fd_sc_hd
# corner: ss=slow(setup), ff=fast(hold), tt=typical
CORNER     ?= ss
LIB_DIR    ?= $(PDK_ROOT)/$(PDK)/libs.ref/$(STD_CELL)/lib
LIB        ?= $(firstword $(wildcard $(LIB_DIR)/$(STD_CELL)__$(CORNER)_*.lib))
SDC        ?= constraints/$(U).sdc
STA        ?= sta
NET        := synth/$(U)_net.v

.PHONY: sta sta-map sta-report

# gate-level netlist mapped to real sky130 cells (separate from `make synth`,
# which is a generic tech-independent check). Reuses sv2v output.
sta-map: sv2v | $(BUILD)
	@[ -n "$(LIB)" ] || { echo "no liberty found in $(LIB_DIR) for corner '$(CORNER)'."; \
		echo "is the PDK installed?  volare enable --pdk sky130  (PDK_ROOT=$(PDK_ROOT))"; exit 1; }
	$(YOSYS) -p "read_verilog synth/$(TOP).v; \
		hierarchy -top $(U); \
		synth -top $(U); \
		dfflibmap -liberty $(LIB); \
		abc -liberty $(LIB); \
		opt_clean -purge; \
		write_verilog -noattr $(NET)"
	@echo "wrote $(NET) (mapped to $(notdir $(LIB)))"

sta: sta-map
	@[ -f "$(SDC)" ] || { echo "no constraints file: $(SDC)"; \
		echo "put your SDC there, or override:  make sta U=$(U) SDC=path/to.sdc"; exit 1; }
	@printf '%s\n' \
		'read_liberty $(LIB)' \
		'read_verilog $(NET)' \
		'link_design $(U)' \
		'read_sdc $(SDC)' \
		'puts "== corner: $(CORNER)  lib: $(notdir $(LIB)) =="' \
		'report_checks -path_delay min_max -digits 3' \
		'report_wns' \
		'report_tns' \
		'report_check_types -max_slew -max_capacitance -max_fanout -violators' \
		> $(BUILD)/sta_$(U).tcl
	$(STA) -no_init -exit $(BUILD)/sta_$(U).tcl | tee $(BUILD)/sta_$(U).rpt
	@echo "report saved: $(BUILD)/sta_$(U).rpt"

sta-report:
	@r=$$(ls -t $(BUILD)/sta_*.rpt 2>/dev/null | head -1); \
	[ -n "$$r" ] && { echo "== $$r =="; cat "$$r"; } || echo "no STA report yet — run 'make sta'"
