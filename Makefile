RTL_DIR = rtl
TB_DIR = tb
BUILD_DIR = build
VERILOG_SV2V = verilog_sv2v

LIBLANE_CONFIG ?= config.json
PYTHON ?= .venv/bin/python
VENV_PYTHON ?= /usr/bin/python3

SV_RTL = $(wildcard $(RTL_DIR)/*.sv)
SV_PKG = $(wildcard $(RTL_DIR)/pkg_*.sv) $(wildcard $(RTL_DIR)/*_pkg.sv)
SV_REST = $(filter-out $(SV_PKG),$(SV_RTL))
V_MODELS = $(wildcard $(RTL_DIR)/*.v)
V_RTL = $(patsubst $(RTL_DIR)/%.sv, $(VERILOG_SV2V)/%.v, $(SV_RTL))

PDK_ROOT ?= $(HOME)/eda/.volare

TB_TOP ?= tb_top
TB_SRC = $(TB_DIR)/$(TB_TOP).sv
SRAM_DIR := sram22_64x32m4w8
SIM_MODELS = $(foreach m,$(V_MODELS), $(if $(wildcard $(SRAM_DIR)/$(notdir $(m))),$(SRAM_DIR)/$(notdir $(m)),$(m)))

XVLOG ?= xvlog
XELAB ?= xelab
XSIM ?= xsim
XSIM_DIR = $(BUILD_DIR)/xsim
XSIM_SNAP = $(TB_TOP)_snap

VECTORS = $(TB_DIR)/vectors/stim.hex $(TB_DIR)/vectors/golden.hex $(TB_DIR)/vectors/tb_params.vh
TB_PLUSARGS = +stim=$(CURDIR)/$(TB_DIR)/vectors/stim.hex +gold=$(CURDIR)/$(TB_DIR)/vectors/golden.hex
XSIM_ARGS = -runall $(addprefix -testplusarg ,$(subst +,,$(TB_PLUSARGS)))

GL_NL := $(if $(RUN),runs/$(RUN)/final/nl/top.nl.v,$(shell ls -t runs/*/final/nl/top.nl.v 2>/dev/null | head -1))
GL_PDK_VERILOG := $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog
GL_PDK_MODELS := $(BUILD_DIR)/primitives.patched.v $(BUILD_DIR)/sky130_fd_sc_hd.patched.v
GL_UNIT_DELAY ?= \#1
GL_DEFS = -d GL -d FUNCTIONAL -d 'UNIT_DELAY=$(GL_UNIT_DELAY)'
GL_TAG := $(subst /,_,$(patsubst runs/%,%,$(patsubst %/final/nl/top.nl.v,%,$(GL_NL))))
GL_XSIM_DIR = $(BUILD_DIR)/xsim_gl_$(GL_TAG)
GL_SNAP = $(TB_TOP)_gl_snap
GL_VCD = $(GL_XSIM_DIR)/$(TB_TOP)_gl.vcd

.PHONY: all venv cocotb xrun gl gl-waves vectors waves xrun-waves \
	sv2v_rtl lint liblane lib-last_run report sta-shell clean

all: cocotb

$(VERILOG_SV2V) $(BUILD_DIR):
	@mkdir -p $@

.DELETE_ON_ERROR:

# Convert the full SV set together so packages (sys_pkg) elaborate correctly.
sv2v_rtl: $(SV_RTL) | $(VERILOG_SV2V)
	@rm -f $(VERILOG_SV2V)/*.v
	@sv2v -DSYNTHESIS $(SV_PKG) $(SV_REST) -w $(VERILOG_SV2V)
	@for f in $(VERILOG_SV2V)/*.v; do \
		tmp=$$(mktemp); echo '`timescale 1ps/1ps' | cat - $$f > $$tmp && mv $$tmp $$f; \
	done

cocotb: vectors $(SV_RTL) $(V_MODELS)
	$(PYTHON) $(TB_DIR)/test_top.py

$(VECTORS) &: $(TB_DIR)/gen_vectors.py rtl/pkg_sys.sv
	$(PYTHON) $(TB_DIR)/gen_vectors.py

vectors: $(VECTORS)

xrun: $(SV_RTL) $(SIM_MODELS) $(TB_SRC) $(VECTORS) | $(BUILD_DIR)
	@mkdir -p $(XSIM_DIR)
	cd $(XSIM_DIR) && \
		$(XVLOG) --sv -i $(CURDIR)/$(TB_DIR) $(addprefix $(CURDIR)/,$(SV_PKG) $(SV_REST) $(TB_SRC)) && \
		$(XVLOG) $(addprefix $(CURDIR)/,$(SIM_MODELS)) && \
		$(XELAB) -debug typical -timescale 1ps/1ps -top $(TB_TOP) -snapshot $(XSIM_SNAP) && \
		$(XSIM) $(XSIM_SNAP) -testplusarg wave=$(TB_TOP).vcd $(XSIM_ARGS)

waves:
	gtkwave $(BUILD_DIR)/cocotb/top.fst &

xrun-waves:
	gtkwave $(XSIM_DIR)/$(TB_TOP).vcd &

venv:
	$(VENV_PYTHON) -m venv .venv
	.venv/bin/pip install --upgrade pip
	.venv/bin/pip install cocotb==2.0.1 numpy

lint:
	verilator --lint-only -Wall --timing $(SV_RTL) $(addprefix -v ,$(V_MODELS))

sta-shell:
	scripts/stadebug $(RUN) $(if $(CORNER),-c $(CORNER),) $(if $(GUI),--gui,)

RUN ?=
LL_RUN    := $(if $(RUN),--run-tag $(RUN),)
LL_RENDER := $(if $(RUN),--run-tag $(RUN),--last-run)
LL_RUNDIR := $(if $(RUN),runs/$(RUN),runs/RUN_*)

liblane: $(V_RTL)
	librelane $(LL_RUN) --to KLayout.StreamOut $(LIBLANE_CONFIG)
	klayout -b -r scripts/strip_orphan_tops.py \
		-rd gds=$$(ls -dt $(LL_RUNDIR)/*-magic-streamout/top.gds | head -1) -rd top=top
	librelane $(LL_RENDER) --from KLayout.Render $(LIBLANE_CONFIG)

lib-last_run:
	librelane --last-run --flow openinopenroad $(LIBLANE_CONFIG)

report:
	python3 scripts/runreport.py $(RUN) $(REPORT_ARGS)

$(BUILD_DIR)/%.patched.v: $(GL_PDK_VERILOG)/%.v Makefile | $(BUILD_DIR)
	sed -E -e 's:^([ \t]*`(endif|else))[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*$$:\1 // \3:' \
	       -e 's:^[ \t]*`default_nettype[ \t]+none[ \t]*$$:`default_nettype wire:' $< > $@

gl: $(VECTORS) $(GL_PDK_MODELS)
	@test -n "$(GL_NL)" || { echo "no netlist found: set RUN=<tag> or GL_NL=<path>"; exit 1; }
	@test -f "$(GL_NL)" || { echo "missing netlist: $(GL_NL)"; exit 1; }
	@echo "gate-level sim on $(GL_NL)"
	@mkdir -p $(GL_XSIM_DIR)
	cd $(GL_XSIM_DIR) && \
		$(XVLOG) $(GL_DEFS) $(addprefix $(CURDIR)/,$(GL_PDK_MODELS)) && \
		$(XVLOG) $(addprefix $(CURDIR)/,$(SIM_MODELS) $(GL_NL)) && \
		$(XVLOG) --sv $(GL_DEFS) -i $(CURDIR)/$(TB_DIR) $(CURDIR)/$(TB_SRC) && \
		$(XELAB) -debug typical -timescale 1ps/1ps -top $(TB_TOP) -snapshot $(GL_SNAP) && \
		$(XSIM) $(GL_SNAP) -testplusarg wave=$(notdir $(GL_VCD)) $(XSIM_ARGS)

gl-waves:
	gtkwave $(GL_VCD) &

clean:
	rm -rf $(BUILD_DIR) $(VERILOG_SV2V) tb/__pycache__ tb/*.xml
	rm -rf *.log *.vcd *.fst *.pb
	rm -rf __pycache__ .pytest_cache
