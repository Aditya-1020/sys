RTL_DIR = rtl
TB_DIR = tb
CONSTRAINTS_DIR = constraints
BUILD_DIR = build
VERILOG_SV2V = verilog_sv2v

LIBLANE_CONFIG ?= config.json
PYTHON ?= .venv/bin/python

SV_RTL = $(wildcard $(RTL_DIR)/*.sv)
V_MODELS = $(wildcard $(RTL_DIR)/*.v)
V_RTL = $(patsubst $(RTL_DIR)/%.sv, $(VERILOG_SV2V)/%.v, $(SV_RTL))

PDK_ROOT ?= $(HOME)/eda/.volare
LIB_DIR ?= $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib
FULL_LIB := $(LIB_DIR)/sky130_fd_sc_hd__tt_025C_1v80.lib
TRIM_LIB := $(BUILD_DIR)/sky130_fd_sc_hd__tt_025C_1v80.trimmed.lib

TT_SYNTH_LIB := $(TRIM_LIB)
TT_STA_LIB := $(FULL_LIB)
STA_SRAM_LIB := sram22_64x32m4w8/patched/sram22_64x32m4w8_tt_025C_1v80.lib

export TT_STA_LIB
export TT_SYNTH_LIB
export STA_SRAM_LIB

SYNTH_TOP ?= systolic_array
SYNTH_V = $(BUILD_DIR)/$(SYNTH_TOP)_synth.v
STA_TOP ?= pe

.PHONY: all cocotb sv2v_rtl synth sta sta-shell lint sram-lib liblane lib-last_run report clean

all: cocotb

$(VERILOG_SV2V) $(BUILD_DIR):
	@mkdir -p $@

.DELETE_ON_ERROR:

$(VERILOG_SV2V)/%.v: $(RTL_DIR)/%.sv | $(VERILOG_SV2V)
	@echo '`timescale 1ps/1ps' > $@
	@sv2v $< >> $@

sv2v_rtl: $(V_RTL)

cocotb: $(V_RTL)
	$(PYTHON) $(TB_DIR)/run_top.py

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

SRAM_DIR := sram22_64x32m4w8
SRAM_GDS := $(SRAM_DIR)/$(SRAM_DIR).gds
SRAM_LEF := $(SRAM_DIR)/$(SRAM_DIR).lef
SRAM_GDS_PATCHED := $(SRAM_DIR)/patched/$(SRAM_DIR).gds

$(SRAM_GDS_PATCHED): $(SRAM_GDS) $(SRAM_LEF) scripts/patch_sram_gds.py
	klayout -b -r scripts/patch_sram_gds.py \
		-rd gds=$(SRAM_GDS) -rd lef=$(SRAM_LEF) -rd out=$@

sram-lib: $(SRAM_GDS_PATCHED)

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
	rm -rf $(BUILD_DIR) $(VERILOG_SV2V) tb/__pycache__
	rm -f *.log
