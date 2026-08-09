RTL_DIR = rtl
TB_DIR = tb
BUILD_DIR = build
VERILOG_SV2V = verilog_sv2v

LIBLANE_CONFIG ?= config.json
PYTHON ?= .venv/bin/python
VENV_PYTHON ?= /usr/bin/python3

SV_RTL = $(wildcard $(RTL_DIR)/*.sv)
V_MODELS = $(wildcard $(RTL_DIR)/*.v)
V_RTL = $(patsubst $(RTL_DIR)/%.sv, $(VERILOG_SV2V)/%.v, $(SV_RTL))

PDK_ROOT ?= $(HOME)/eda/.volare
LIB_DIR ?= $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib
MAGIC_RCFILE ?= $(PDK_ROOT)/sky130A/libs.tech/magic/sky130A.magicrc
FULL_LIB := $(LIB_DIR)/sky130_fd_sc_hd__tt_025C_1v80.lib
TRIM_LIB := $(BUILD_DIR)/sky130_fd_sc_hd__tt_025C_1v80.trimmed.lib

SRAM_DIR := sram22_64x32m4w8
SRAM_BUILD := $(BUILD_DIR)/$(SRAM_DIR)
SRAM_GDS := $(SRAM_DIR)/$(SRAM_DIR).gds
SRAM_LEF := $(SRAM_DIR)/$(SRAM_DIR).lef
SRAM_CORNERS := tt_025C_1v80 ss_100C_1v60 ff_n40C_1v95
SRAM_LIBS := $(patsubst %,$(SRAM_BUILD)/$(SRAM_DIR)_%.lib,$(SRAM_CORNERS))
SRAM_LEF_OUT := $(SRAM_BUILD)/$(SRAM_DIR).lef
SRAM_GDS_OUT := $(SRAM_BUILD)/$(SRAM_DIR).gds
SRAM_MAGLEF := $(SRAM_DIR)/$(SRAM_DIR).mag

TT_SYNTH_LIB := $(TRIM_LIB)
TT_STA_LIB := $(FULL_LIB)
STA_SRAM_LIB := $(SRAM_BUILD)/$(SRAM_DIR)_tt_025C_1v80.lib

export TT_STA_LIB
export TT_SYNTH_LIB
export STA_SRAM_LIB

SYNTH_TOP ?= systolic_array
SYNTH_V = $(BUILD_DIR)/$(SYNTH_TOP)_synth.v
STA_TOP ?= pe

TB_TOP ?= tb_top
TB_SRC = $(TB_DIR)/$(TB_TOP).sv
SIM_MODELS = $(foreach m,$(V_MODELS), $(if $(wildcard $(SRAM_DIR)/$(notdir $(m))),$(SRAM_DIR)/$(notdir $(m)),$(m)))

XVLOG ?= xvlog
XELAB ?= xelab
XSIM ?= xsim
XSIM_DIR = $(BUILD_DIR)/xsim
XSIM_SNAP = $(TB_TOP)_snap

.PHONY: all venv cocotb xrun gl gl-waves prof vectors waves xrun-waves sv2v_rtl synth sta sta-shell lint sram liblane lib-last_run report clean

all: cocotb

VECTORS = $(TB_DIR)/vectors/stim.hex $(TB_DIR)/vectors/golden.hex $(TB_DIR)/vectors/tb_params.vh

$(VERILOG_SV2V) $(BUILD_DIR):
	@mkdir -p $@

.DELETE_ON_ERROR:

$(VERILOG_SV2V)/%.v: $(RTL_DIR)/%.sv | $(VERILOG_SV2V)
	@echo '`timescale 1ps/1ps' > $@
	@sv2v -DSYNTHESIS $< >> $@

sv2v_rtl: $(V_RTL)

cocotb: $(SV_RTL) $(V_MODELS)
	$(PYTHON) $(TB_DIR)/test_top.py

PROF_TILES ?=
PROF_BATCH ?=
prof: $(SV_RTL) $(V_MODELS)
	$(if $(PROF_TILES),PROF_TILES=$(PROF_TILES) ,)$(if $(PROF_BATCH),PROF_BATCH=$(PROF_BATCH) ,)$(PYTHON) $(TB_DIR)/prof.py

$(VECTORS) &: $(TB_DIR)/test_top.py
	$(PYTHON) $(TB_DIR)/test_top.py --gen

vectors: $(VECTORS)

TB_PLUSARGS = +stim=$(CURDIR)/$(TB_DIR)/vectors/stim.hex +gold=$(CURDIR)/$(TB_DIR)/vectors/golden.hex

XSIM_ARGS = -runall $(addprefix -testplusarg ,$(subst +,,$(TB_PLUSARGS)))

xrun: $(SV_RTL) $(SIM_MODELS) $(TB_SRC) $(VECTORS) | $(BUILD_DIR)
	@mkdir -p $(XSIM_DIR)
	cd $(XSIM_DIR) && \
		$(XVLOG) --sv -i $(CURDIR)/$(TB_DIR) $(addprefix $(CURDIR)/,$(SV_RTL) $(TB_SRC)) && \
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

$(TRIM_LIB): $(FULL_LIB) scripts/filter_lib.py | $(BUILD_DIR)
	python3 scripts/filter_lib.py $< $@

$(SYNTH_V): $(V_RTL) $(TRIM_LIB) scripts/$(SYNTH_TOP)/synth.tcl | $(BUILD_DIR)
	yosys -c scripts/$(SYNTH_TOP)/synth.tcl

synth: $(SYNTH_V)

sta: $(V_RTL) $(TRIM_LIB) $(STA_SRAM_LIB) scripts/$(STA_TOP)/synth.tcl scripts/$(STA_TOP)/sta.tcl | $(BUILD_DIR)
	yosys -c scripts/$(STA_TOP)/synth.tcl
	sta   scripts/$(STA_TOP)/sta.tcl

sta-shell:
	scripts/stadebug $(RUN) $(if $(CORNER),-c $(CORNER),) $(if $(GUI),--gui,)

$(SRAM_LIBS) $(SRAM_LEF_OUT) &: $(wildcard $(SRAM_DIR)/*.lib) $(SRAM_LEF) scripts/build_sram_macro.py | $(BUILD_DIR)
	python3 scripts/build_sram_macro.py --src $(SRAM_DIR) --out $(SRAM_BUILD)

$(SRAM_GDS_OUT): $(SRAM_GDS) $(SRAM_LEF) scripts/patch_sram_gds.py | $(BUILD_DIR)
	klayout -b -r scripts/patch_sram_gds.py \
		-rd gds=$(SRAM_GDS) -rd lef=$(SRAM_LEF) -rd out=$@

$(SRAM_MAGLEF): $(SRAM_LEF_OUT) scripts/sram_maglef.tcl
	magic -dnull -noconsole -rcfile $(MAGIC_RCFILE) \
		scripts/sram_maglef.tcl $(SRAM_LEF_OUT) $(SRAM_DIR)

sram: $(SRAM_LIBS) $(SRAM_LEF_OUT) $(SRAM_GDS_OUT) $(SRAM_MAGLEF)

GL_NL := $(if $(RUN),runs/$(RUN)/final/nl/top.nl.v,$(shell ls -t runs/*/final/nl/top.nl.v 2>/dev/null | head -1))
GL_PDK_VERILOG := $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog
GL_PDK_MODELS := $(BUILD_DIR)/primitives.patched.v $(BUILD_DIR)/sky130_fd_sc_hd.patched.v
GL_UNIT_DELAY ?= \#1
GL_DEFS = -d GL -d FUNCTIONAL -d 'UNIT_DELAY=$(GL_UNIT_DELAY)'

GL_TAG := $(subst /,_,$(patsubst runs/%,%,$(patsubst %/final/nl/top.nl.v,%,$(GL_NL))))
GL_XSIM_DIR = $(BUILD_DIR)/xsim_gl_$(GL_TAG)
GL_SNAP = $(TB_TOP)_gl_snap
GL_VCD = $(GL_XSIM_DIR)/$(TB_TOP)_gl.vcd


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

lib-last_run:
	librelane --last-run --flow openinopenroad $(LIBLANE_CONFIG)

report:
	python3 scripts/runreport.py $(RUN) $(REPORT_ARGS)

clean:
	rm -rf $(BUILD_DIR) $(VERILOG_SV2V) tb/__pycache__ tb/*.xml
	rm -rf *.log *.vcd *.fst *.pb