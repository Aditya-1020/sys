RTL_DIR = rtl
TB_DIR = tb
CONSTRAINTS_DIR = constraints
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

.PHONY: all venv cocotb prof vectors waves sv2v_rtl synth sta sta-shell sta-probe lint sram liblane lib-last_run report clean

all: cocotb

VECTORS = $(TB_DIR)/vectors/stim.hex $(TB_DIR)/vectors/golden.hex

$(VERILOG_SV2V) $(BUILD_DIR):
	@mkdir -p $@

.DELETE_ON_ERROR:

$(VERILOG_SV2V)/%.v: $(RTL_DIR)/%.sv | $(VERILOG_SV2V)
	@echo '`timescale 1ps/1ps' > $@
	@sv2v -DSYNTHESIS $< >> $@

sv2v_rtl: $(V_RTL)

cocotb: $(SV_RTL) $(V_MODELS)
	$(PYTHON) $(TB_DIR)/test_top.py

# throughput gate for perf checks PROF_TILES=N for a longer run.
PROF_TILES ?=
PROF_BATCH ?=
prof: $(SV_RTL) $(V_MODELS)
	$(if $(PROF_TILES),PROF_TILES=$(PROF_TILES) ,)$(if $(PROF_BATCH),PROF_BATCH=$(PROF_BATCH) ,)$(PYTHON) $(TB_DIR)/prof.py

$(VECTORS) &: $(TB_DIR)/test_top.py
	$(PYTHON) $(TB_DIR)/test_top.py --gen

vectors: $(VECTORS)

waves:
	gtkwave $(BUILD_DIR)/cocotb/top.fst &

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

# PROBES=<file> POSTPNR=1 SAVE=<tag> CHECK=1
# sta-probe:
# 	scripts/stapath -f $(PROBES) \
# 		$(if $(POSTPNR),--run $(RUN),) $(if $(CORNER),--corner $(CORNER),) \
# 		$(if $(SAVE),--save $(SAVE),) $(if $(CHECK),--check,) $(STAPATH_ARGS)

$(SRAM_LIBS) $(SRAM_LEF_OUT) &: $(wildcard $(SRAM_DIR)/*.lib) $(SRAM_LEF) scripts/build_sram_macro.py | $(BUILD_DIR)
	python3 scripts/build_sram_macro.py --src $(SRAM_DIR) --out $(SRAM_BUILD)

$(SRAM_GDS_OUT): $(SRAM_GDS) $(SRAM_LEF) scripts/patch_sram_gds.py | $(BUILD_DIR)
	klayout -b -r scripts/patch_sram_gds.py \
		-rd gds=$(SRAM_GDS) -rd lef=$(SRAM_LEF) -rd out=$@

$(SRAM_MAGLEF): $(SRAM_LEF_OUT) scripts/sram_maglef.tcl
	magic -dnull -noconsole -rcfile $(MAGIC_RCFILE) \
		scripts/sram_maglef.tcl $(SRAM_LEF_OUT) $(SRAM_DIR)

sram: $(SRAM_LIBS) $(SRAM_LEF_OUT) $(SRAM_GDS_OUT) $(SRAM_MAGLEF)

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

clean:
	rm -rf $(BUILD_DIR) $(VERILOG_SV2V) tb/__pycache__ tb/*.xml
	rm -f *.log
