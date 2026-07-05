# Project: systolic
# Self-contained: standard targets come from ./mk (vendored by hwnew/hwmk)
# setup. `make help` lists targets

TOP  := systolic_array
SRCS := $(wildcard rtl/*.sv)
# INC_DIRS     := rtl rtl/include
# UNIT_TB_SRCS := tb/tb_pkg.sv       # shared tb packages/interfaces, if any
# CONSTRAINTS_DIR := constraints

include mk/common.mk
include mk/sim.mk
# include mk/formal.mk
include mk/asic.mk
include mk/sta.mk

# project-specific targets below this line
