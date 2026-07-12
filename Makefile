RTL_DIR = rtl
TB_DIR = tb
CONSTRAINTS_DIR = constraints
BUILD_DIR = build
VERILOG_SV2V = verilog_sv2v

# openram macro + its wrapper are not converted/simulated;
# tb/sram_stub.sv provides sram_model for simulation
SRAM_GEN  = $(RTL_DIR)/sky130_sram_1kbyte_1rw1r_32x256_8.v
SRAM_WRAP = $(RTL_DIR)/sram_model.sv

SV_RTL = $(filter-out $(SRAM_WRAP), $(wildcard $(RTL_DIR)/*.sv))
SV_TB = $(wildcard $(TB_DIR)/*.sv)
V_RTL = $(patsubst $(RTL_DIR)/%.sv, $(VERILOG_SV2V)/%.v, $(SV_RTL))
V_SIM_SRCS = $(V_RTL) $(SV_TB)

TOP = tb_systolic_array
SNAPSHOT = $(TOP)_snap

# STA: scripts in scripts/<module>/{synth,sta}.tcl, sdc in constraints/<module>.sdc
PDK_ROOT ?= $(HOME)/eda/.volare
STA_TOP ?= pe
LIB_DIR ?= $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib
TT_STA_LIB ?= $(LIB_DIR)/sky130_fd_sc_hd__tt_025C_1v80.lib

export TT_STA_LIB

.PHONY: all wave xcompile xelab xrun xgui sta lint clean sv2v_rtl

all: xrun

$(VERILOG_SV2V) $(BUILD_DIR):
	mkdir -p $@

$(VERILOG_SV2V)/%.v: $(RTL_DIR)/%.sv | $(VERILOG_SV2V)
	echo '`timescale 1ps/1ps' > $@
	sv2v $< >> $@

sv2v_rtl: $(V_RTL)

xcompile: $(V_RTL)
	xvlog -sv $(V_SIM_SRCS)

xelab: xcompile
	xelab -debug typical -top $(TOP) -snapshot $(SNAPSHOT)

xrun: xelab
	xsim $(SNAPSHOT) -R

xgui: xelab
	xsim $(SNAPSHOT) -gui &

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
