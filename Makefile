RTL_DIR = rtl
TB_DIR = tb
CONSTRAINTS_DIR = constraints
BUILD_DIR = build
VERILOG_SV2V = verilog_sv2v

SV_RTL = $(wildcard $(RTL_DIR)/*.sv)
SV_TB = $(wildcard $(TB_DIR)/*.sv)
V_RTL = $(patsubst $(RTL_DIR)/%.sv, $(VERILOG_SV2V)/%.v, $(SV_RTL))
V_SIM_SRCS = $(V_RTL) $(SV_TB)

IVERILOG_FLAGS = -g2012 -Wall
IVERILOG_OUT   = $(BUILD_DIR)/sim.vvp

TOP = tb_systolic_array
SNAPSHOT = $(TOP)_snap

# STA: scripts in scripts/<module>/{synth,sta}.tcl, sdc in constraints/<module>.sdc
PDK_ROOT ?= $(HOME)/eda/.volare
STA_TOP ?= pe
LIB_DIR ?= $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib
TT_STA_LIB ?= $(LIB_DIR)/sky130_fd_sc_hd__tt_025C_1v80.lib

export TT_STA_LIB

.PHONY: all compile run wave xcompile xelab xrun xgui sta lint clean sv2v_rtl

all: run

$(VERILOG_SV2V) $(BUILD_DIR):
	mkdir -p $@

$(VERILOG_SV2V)/%.v: $(RTL_DIR)/%.sv | $(VERILOG_SV2V)
	echo '`timescale 1ps/1ps' > $@
	sv2v $< > $@

sv2v_rtl: $(V_RTL)

compile: $(V_RTL) | $(BUILD_DIR)
	iverilog $(IVERILOG_FLAGS) -o $(IVERILOG_OUT) $(V_SIM_SRCS)

run: compile
	vvp $(IVERILOG_OUT)

wave:
	gtkwave dump.vcd &

xcompile: $(V_RTL)
	xvlog -sv $(V_SIM_SRCS)

# xelab -debug typical -top $(TOP) -snapshot $(SNAPSHOT)
xelab: xcompile
	xelab -debug typical -top $(TOP) -snapshot $(SNAPSHOT)

xrun: xelab
	xsim $(SNAPSHOT) -R

xgui: xelab
	xsim $(SNAPSHOT) -gui &

# make sta STA_TOP=module_name (change lib in TT_STA_LIB if needed)
sta: $(VERILOG_SV2V)/$(STA_TOP).v | $(BUILD_DIR)
	yosys -c scripts/$(STA_TOP)/synth.tcl
	sta   scripts/$(STA_TOP)/sta.tcl

lint:
	verilator --lint-only -Wall --timing $(SV_RTL) $(SV_TB)

# $(VERILOG_SV2V)
clean:
	rm -rf $(BUILD_DIR)  xsim.dir .Xil
	rm -f dump.vcd *.pb *.log *.wdb *.jou *.str *.vcdv