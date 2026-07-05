# lint + per-unit simulation
# Requires common.mk included first.

# Unit test conventions - for a module <u> in rtl/, any/all of:
#   tb/tb_<u>.sv     SV testbench (module tb_<u>)       -> icarus (SIM=verilator to switch)
#   tb/tb_<u>.cpp    verilator C++ harness around V<u>  -> verilator --cc
#   tb/test_<u>.py   cocotb test module (dut = <u>)     -> cocotb  (COCOTB_SIM=icarus)
#
# Dependency handling: all of $(SRCS) is passed every time; the simulator
# elaborates only the hierarchy under the chosen top, so each unit pulls in
# exactly the submodules it instantiates. No per-unit file lists to maintain.
# Override UNIT_SRCS for the rare unit that needs a restricted/extra set.

U            ?= $(TOP)
SIM          ?= icarus    # simulator for SV testbenches: icarus | verilator
COCOTB_SIM   ?= icarus    # cocotb backend (icarus | verilator | ...)
UNIT_SRCS    ?= $(SRCS)   # DUT sources visible to a unit
UNIT_TB_SRCS ?=           # shared tb-side files (packages, interfaces), if any

# every unit that has at least one TB
UNITS := $(sort \
  $(patsubst tb/tb_%.sv,%,$(wildcard tb/tb_*.sv)) \
  $(patsubst tb/tb_%.cpp,%,$(wildcard tb/tb_*.cpp)) \
  $(patsubst tb/test_%.py,%,$(wildcard tb/test_*.py)))

VERILATOR_FLAGS ?= -Wall --timing --trace-fst --assert -j 0

.PHONY: lint sim unit units list-units unit-sv unit-cpp unit-py waves

# lint
lint:
	$(VERILATOR) --lint-only -Wall --timing $(INCFLAGS) --top-module $(TOP) $(SRCS)
	@command -v $(VERIBLE_LINT) >/dev/null && \
		$(VERIBLE_LINT) --rules=-line-length $(SRCS) || \
		echo "(verible not installed, style lint skipped)"

# unit dispatch
sim:
	@$(MAKE) --no-print-directory unit U=$(TOP)

# run every TB style that exists for $(U); fail if there is none
unit:
	@found=0; \
	if [ -f tb/tb_$(U).sv ];   then $(MAKE) --no-print-directory unit-sv  U=$(U) || exit 1; found=1; fi; \
	if [ -f tb/tb_$(U).cpp ];  then $(MAKE) --no-print-directory unit-cpp U=$(U) || exit 1; found=1; fi; \
	if [ -f tb/test_$(U).py ]; then $(MAKE) --no-print-directory unit-py  U=$(U) || exit 1; found=1; fi; \
	[ $$found -eq 1 ] || \
		{ echo "no TB for '$(U)' - want tb/tb_$(U).sv, tb/tb_$(U).cpp or tb/test_$(U).py"; exit 1; }

# run everything (CI entry point)
units:
	@[ -n "$(UNITS)" ] || { echo "no unit TBs found in tb/"; exit 0; }; \
	fail=0; \
	for u in $(UNITS); do \
		echo "== unit $$u =="; \
		$(MAKE) --no-print-directory unit U=$$u || fail=1; \
	done; \
	exit $$fail

list-units:
	@echo $(UNITS)

# SV testbench
unit-sv: | $(BUILD)
ifeq ($(SIM),verilator)
	$(VERILATOR) $(VERILATOR_FLAGS) --binary $(INCFLAGS) --top-module tb_$(U) \
		$(UNIT_SRCS) $(UNIT_TB_SRCS) tb/tb_$(U).sv -Mdir $(BUILD)/obj_tb_$(U) -o tb_$(U)
	$(BUILD)/obj_tb_$(U)/tb_$(U)
else
	$(IVERILOG) -g2012 $(INCFLAGS) -s tb_$(U) -o $(BUILD)/tb_$(U).vvp \
		$(UNIT_SRCS) $(UNIT_TB_SRCS) tb/tb_$(U).sv
	cd $(BUILD) && $(VVP) tb_$(U).vvp
endif

# verilator C++ harness
unit-cpp: | $(BUILD)
	$(VERILATOR) $(VERILATOR_FLAGS) --cc $(INCFLAGS) --top-module $(U) \
		$(UNIT_SRCS) --exe $(abspath tb/tb_$(U).cpp) -Mdir $(BUILD)/obj_$(U)
	$(MAKE) -C $(BUILD)/obj_$(U) -f V$(U).mk
	$(BUILD)/obj_$(U)/V$(U)

# cocotb
# Needs `pip install cocotb`. Both old (1.x) and new (2.x) variable names are
# passed
unit-py: export PYTHONPATH := $(abspath tb):$(PYTHONPATH)
unit-py: | $(BUILD)
	@command -v cocotb-config >/dev/null || \
		{ echo "cocotb not installed: pip install cocotb"; exit 1; }
	$(MAKE) -f $$(cocotb-config --makefiles)/Makefile.sim \
		SIM=$(COCOTB_SIM) TOPLEVEL_LANG=verilog \
		VERILOG_SOURCES="$(abspath $(UNIT_SRCS))" \
		TOPLEVEL=$(U) COCOTB_TOPLEVEL=$(U) \
		MODULE=test_$(U) COCOTB_TEST_MODULES=test_$(U) \
		SIM_BUILD=$(abspath $(BUILD))/cocotb_$(U) \
		COCOTB_RESULTS_FILE=$(abspath $(BUILD))/cocotb_$(U)/results.xml

# waves
waves:
	@f=$$(ls -t $(BUILD)/*.fst $(BUILD)/*.vcd *.fst *.vcd 2>/dev/null | head -1); \
	if [ -n "$$f" ]; then $(WAVEVIEW) "$$f" & else echo "no waveform dump found"; fi
