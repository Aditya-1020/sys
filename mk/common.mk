# mk/common.mk
TOP        ?= top
SRCS       ?= $(wildcard rtl/*.sv rtl/*.v)
INC_DIRS   ?= rtl
BUILD      ?= build

VERILATOR  ?= verilator
IVERILOG   ?= iverilog
VVP        ?= vvp
YOSYS      ?= yosys
SV2V       ?= sv2v
SBY        ?= sby
VERIBLE_LINT ?= verible-verilog-lint

INCFLAGS   := $(addprefix -I,$(INC_DIRS))

# waveform viewer: surfer if installed, else gtkwave
WAVEVIEW   ?= $(shell command -v surfer >/dev/null && echo surfer || echo gtkwave)

$(BUILD):
	@mkdir -p $(BUILD)

.PHONY: clean help
clean:
	rm -rf $(BUILD) synth/*.json synth/*.rpt synth/*.v obj_dir *.vcd *.fst
	rm -rf tb/__pycache__/

help:
	@echo "TOP=$(TOP)"
	@echo ""
	@echo "  lint           verilator --lint-only + verible style lint"
	@echo "  sim            unit test of TOP (== unit U=$(TOP))"
	@echo "  unit U=<mod>   run <mod>'s TB(s): tb/tb_<mod>.sv|.cpp, tb/test_<mod>.py"
	@echo "  units          run every unit TB found in tb/"
	@echo "  list-units     show detected units"
	@echo "  waves          open latest dump in $(WAVEVIEW)"
	@echo "  formal         all sby targets in formal/ (formal-<name> for one)"
	@echo "  synth          yosys generic synth check (latch/size report)"
	@echo "  sv2v           convert SRCS to Verilog-2005 in synth/"
	@echo "  sta U=<mod>    pre-layout gate-level STA vs PDK (constraints/<mod>.sdc)"
	@echo "  gds            LibreLane full flow (needs config.yaml)"
	@echo "  summary        metrics of latest LibreLane run"
	@echo "  clean          remove generated files"
	@echo ""
	@echo "  knobs: U=<mod>  SIM=icarus|verilator  COCOTB_SIM=icarus  UNIT_SRCS=..."
	@echo "         CORNER=ss|ff|tt (sta)  SDC=path (sta)"
