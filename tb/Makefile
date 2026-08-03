ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
PYTHON ?= $(ROOT)/.venv/bin/python
BUILD = $(ROOT)/build/cocotb

.PHONY: all sim waves clean

all: sim

sim:
	$(MAKE) -C $(ROOT) sv2v_rtl
	$(PYTHON) $(ROOT)/tb/run_top.py

waves:
	gtkwave $(BUILD)/top.fst &

clean:
	rm -rf $(BUILD) __pycache__ results.xml
