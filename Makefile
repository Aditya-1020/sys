RTL_DIR = rtl
TB_DIR = tb
CONSTRAINTS_DIR = constraints
BUILD_DIR = build
VERILOG_SV2V = verilog_sv2v

SV_RTL = $(wildcard $(RTL_DIR)/*.sv)
SV_TB = $(wildcard $(TB_DIR)/*.sv)
V_RTL = $(patsubst $(RTL_DIR)/%.sv, $(VERILOG_SV2V)/%.v, $(SV_RTL))
V_SIM_SRCS = $(V_RTL) $(SV_TB)

TOP = tb_systolic_array
SNAPSHOT = $(TOP)_snap

# make xrun DUMP=1
# array size

N ?= 4
DW ?= 8
SIM_GENERICS = -generic_top "N=$(N)" -generic_top "DW=$(DW)"
ifeq ($(DUMP),1)
  SIM_DEFS = -d DUMP
endif

SYNTH_TOP = systolic_array
SYNTH_V = $(BUILD_DIR)/$(SYNTH_TOP)_synth.v
CELL_V_DIR = $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog

GLS_CELL_DIR = $(BUILD_DIR)/gls_cells
GLS_CELLS = $(GLS_CELL_DIR)/primitives.v $(GLS_CELL_DIR)/sky130_fd_sc_hd.v
GLS_SNAPSHOT = $(TOP)_gls_snap

# STA: scripts in scripts/<module>/{synth,sta}.tcl, sdc in constraints/<module>.sdc
PDK_ROOT ?= $(HOME)/eda/.volare
STA_TOP ?= pe
LIB_DIR ?= $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib
TT_STA_LIB ?= $(LIB_DIR)/sky130_fd_sc_hd__tt_025C_1v80.lib

export TT_STA_LIB

.PHONY: all wave xcompile xelab xrun xgui synth gls sta lint clean sv2v_rtl

all: xrun

$(VERILOG_SV2V) $(BUILD_DIR):
	mkdir -p $@

$(VERILOG_SV2V)/%.v: $(RTL_DIR)/%.sv | $(VERILOG_SV2V)
	echo '`timescale 1ps/1ps' > $@
	sv2v $< >> $@

sv2v_rtl: $(V_RTL)

xcompile: $(V_RTL)
	xvlog -sv $(SIM_DEFS) $(V_SIM_SRCS)

xelab: xcompile
	xelab -debug typical -top $(TOP) -snapshot $(SNAPSHOT) $(SIM_GENERICS)

xrun: xelab
	xsim $(SNAPSHOT) -R

xgui: xelab
	xsim $(SNAPSHOT) -gui &

$(SYNTH_V): $(V_RTL) scripts/$(SYNTH_TOP)/synth.tcl | $(BUILD_DIR)
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

# make sta STA_TOP=module_name (change lib in TT_STA_LIB if needed)
sta: $(VERILOG_SV2V)/$(STA_TOP).v | $(BUILD_DIR)
	yosys -c scripts/$(STA_TOP)/synth.tcl
	sta   scripts/$(STA_TOP)/sta.tcl

lint:
	verilator --lint-only -Wall --timing $(SV_RTL) $(SV_TB)

clean:
	rm -rf $(BUILD_DIR) $(VERILOG_SV2V) xsim.dir .Xil
	rm -f dump.vcd *.pb *.log *.wdb *.jou *.str
