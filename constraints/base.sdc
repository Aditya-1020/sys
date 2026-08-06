# Single-sourced from CLOCK_PERIOD in config.json (also ABC's delay target during
# synthesis). Falls back to 10.0 when read outside the librelane flow.
set SYS_PERIOD [expr {[info exists ::env(CLOCK_PERIOD)] ? $::env(CLOCK_PERIOD) : 10.0}]

create_clock -name SYS_CLK -period $SYS_PERIOD [get_ports clk]
set_clock_transition 0.15 [get_clocks SYS_CLK]

set_false_path -from [get_ports rstn]

set AXI_INPUTS  [get_ports -quiet {i_s_axil_* i_m_axi_*}]
set AXI_OUTPUTS [get_ports -quiet {o_s_axil_* o_m_axi_*}]

set INPUT_DELAY_MAX  [expr {0.30 * $SYS_PERIOD}]
set INPUT_DELAY_MIN  [expr {0.25 * $SYS_PERIOD}]
set OUTPUT_DELAY_MAX [expr {0.20 * $SYS_PERIOD}]
set OUTPUT_DELAY_MIN 0.00

set_input_delay  -clock SYS_CLK -max $INPUT_DELAY_MAX  $AXI_INPUTS
set_input_delay  -clock SYS_CLK -min $INPUT_DELAY_MIN  $AXI_INPUTS
set_output_delay -clock SYS_CLK -max $OUTPUT_DELAY_MAX $AXI_OUTPUTS
set_output_delay -clock SYS_CLK -min $OUTPUT_DELAY_MIN $AXI_OUTPUTS

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X $AXI_INPUTS
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X [get_ports rstn]

set_input_transition 0.10 [get_ports clk]
set_input_transition 0.15 $AXI_INPUTS
set_input_transition 0.15 [get_ports rstn]

set_load 0.03 $AXI_OUTPUTS
set_max_capacitance 0.035 $AXI_OUTPUTS

set SRAM_DOUT_PINS [get_pins {*u_m0/dout* *u_m1/dout*}]
if {[llength $SRAM_DOUT_PINS] != 64} {
    error "base.sdc: expected 64 SRAM dout pins, got [llength $SRAM_DOUT_PINS]"
}
set_max_capacitance 0.025 $SRAM_DOUT_PINS
set SRAM_RSTB_PINS [get_pins {*u_m0/rstb *u_m1/rstb}]
if {[llength $SRAM_RSTB_PINS] != 2} {
    error "base.sdc: expected 2 SRAM rstb pins, got [llength $SRAM_RSTB_PINS]"
}
set_false_path -hold -to $SRAM_RSTB_PINS