RTL_DIR = rtl
TB_DIR = tb
CONSTRAINTS_DIR = constraints
BUILD_DIR = build
VERILOG_SV2V = verilog_sv2v

LIBLANE_CONFIG ?= config.json

SV_RTL = $(wildcard $(RTL_DIR)/*.sv)
SV_TB = $(wildcard $(TB_DIR)/*.sv)
V_MODELS = $(wildcard $(RTL_DIR)/*.v)
V_RTL = $(patsubst $(RTL_DIR)/%.sv, $(VERILOG_SV2V)/%.v, $(SV_RTL))
V_SIM_SRCS = $(V_RTL) $(SV_TB)

TOP = tb_systolic_array
SNAPSHOT = $(TOP)_snap

N ?= 4
DW ?= 8
SIM_GENERICS_tb_systolic_array = -generic_top "N=$(N)" -generic_top "DW=$(DW)"
SIM_GENERICS = $(SIM_GENERICS_$(TOP))
ifeq ($(DUMP),1)
  SIM_DEFS = -d DUMP
endif

SYNTH_TOP = systolic_array
SYNTH_V = $(BUILD_DIR)/$(SYNTH_TOP)_synth.v
CELL_V_DIR = $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog

GLS_CELL_DIR = $(BUILD_DIR)/gls_cells
GLS_CELLS = $(GLS_CELL_DIR)/primitives.v $(GLS_CELL_DIR)/sky130_fd_sc_hd.v
GLS_SNAPSHOT = $(TOP)_gls_snap

PDK_ROOT ?= $(HOME)/eda/.volare
LIB_DIR ?= $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib
FULL_LIB := $(LIB_DIR)/sky130_fd_sc_hd__tt_025C_1v80.lib
TRIM_LIB := $(BUILD_DIR)/sky130_fd_sc_hd__tt_025C_1v80.trimmed.lib

TT_SYNTH_LIB := $(TRIM_LIB)
TT_STA_LIB := $(FULL_LIB)

STA_SRAM_LIB := sram/sky130_sram_1kbyte_1rw1r_32x256_8_TT_1p8V_25C.lib

export TT_STA_LIB
export TT_SYNTH_LIB
export STA_SRAM_LIB

STA_TOP ?= pe

.PHONY: all wave xcompile xelab xrun xgui synth gls sta lint clean sv2v_rtl sweep liblane lib-last_run report sta-shell

all: xrun

$(VERILOG_SV2V) $(BUILD_DIR):
	@mkdir -p $@

$(TRIM_LIB): $(FULL_LIB) scripts/filter_lib.py | $(BUILD_DIR)
	python3 scripts/filter_lib.py $< $@

$(VERILOG_SV2V)/%.v: $(RTL_DIR)/%.sv | $(VERILOG_SV2V)
	@echo '`timescale 1ps/1ps' > $@
	@sv2v $< >> $@

sv2v_rtl: $(V_RTL)

xcompile: $(V_RTL)
	$(if $(V_MODELS),xvlog --relax $(SIM_DEFS) $(V_MODELS))
	xvlog -sv $(SIM_DEFS) $(V_SIM_SRCS)

xelab: xcompile
	xelab -debug typical -timescale 1ps/1ps -top $(TOP) -snapshot $(SNAPSHOT) $(SIM_GENERICS)

xrun: xelab
	xsim $(SNAPSHOT) -R

xgui: xelab
	xsim $(SNAPSHOT) -gui &

$(SYNTH_V): $(V_RTL) $(TRIM_LIB) scripts/$(SYNTH_TOP)/synth.tcl | $(BUILD_DIR)
	yosys -c scripts/$(SYNTH_TOP)/synth.tcl

synth: $(SYNTH_V)

$(GLS_CELL_DIR)/%.v: $(CELL_V_DIR)/%.v | $(BUILD_DIR)
	mkdir -p $(GLS_CELL_DIR)
	sed -e 's/`default_nettype none/`default_nettype wire/' \
	    -e 's/^`endif \([A-Za-z_]\)/`endif \/\/ \1/' $< > $@

gls: $(SYNTH_V) $(GLS_CELLS)
	xvlog -sv -d GLS -d FUNCTIONAL -d "UNIT_DELAY=#1" $(GLS_CELLS) $(SYNTH_V) $(SV_TB)
	xelab -debug typical -top $(TOP) -snapshot $(GLS_SNAPSHOT)
	xsim $(GLS_SNAPSHOT) -R

wave:
	gtkwave dump.vcd &

sta: $(V_RTL) $(TRIM_LIB) $(STA_SRAM_LIB) scripts/$(STA_TOP)/synth.tcl scripts/$(STA_TOP)/sta.tcl $(CONSTRAINTS_DIR)/$(STA_TOP).sdc | $(BUILD_DIR)
	yosys -c scripts/$(STA_TOP)/synth.tcl
	sta   scripts/$(STA_TOP)/sta.tcl

lint:
	verilator --lint-only -Wall --timing lint.vlt $(SV_RTL) $(SV_TB) $(addprefix -v ,$(V_MODELS))

RUN ?=
LL_RUN    := $(if $(RUN),--run-tag $(RUN),)
LL_RENDER := $(if $(RUN),--run-tag $(RUN),--last-run)
LL_RUNDIR := $(if $(RUN),runs/$(RUN),runs/RUN_*)

liblane: $(V_RTL)
	librelane $(LL_RUN) --to KLayout.StreamOut $(LIBLANE_CONFIG)
	klayout -b -r scripts/strip_orphan_tops.py \
		-rd gds=$$(ls -dt $(LL_RUNDIR)/*-magic-streamout/top.gds | head -1) -rd top=top
	librelane $(LL_RENDER) --from KLayout.Render $(LIBLANE_CONFIG)

sweep: $(V_RTL)
	@tclsh scripts/sweep.tcl

lib-last_run:
	librelane --last-run --flow openinopenroad $(LIBLANE_CONFIG)

report:
	python3 scripts/runreport.py $(RUN) $(REPORT_ARGS)

sta-shell:
	scripts/stadebug $(RUN) $(if $(CORNER),-c $(CORNER),) $(if $(GUI),--gui,)

clean:
	rm -rf $(BUILD_DIR) $(VERILOG_SV2V) xsim.dir .Xil
	rm -f dump.vcd *.pb *.log *.wdb *.jou *.str