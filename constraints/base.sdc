set SYS_PERIOD [expr {[info exists ::env(CLOCK_PERIOD)] ? $::env(CLOCK_PERIOD) : 10.0}]

create_clock -name SYS_CLK -period $SYS_PERIOD [get_ports clk]
set_clock_transition 0.15 [get_clocks SYS_CLK]

set_clock_uncertainty -setup 0.25 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.08 [get_clocks SYS_CLK]

set_timing_derate -early 0.99
set_timing_derate -late  1.01

# 0.65
set_max_transition 1.6 [current_design]
set_max_fanout 16 [current_design]

set_false_path -from [get_ports rstn]

set_false_path -to [get_pins {u_sram.u_m0/rstb u_sram.u_m1/rstb}]

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X [get_ports rstn]
set_input_transition 0.15 [get_ports rstn]

set AXI_INPUTS  [get_ports -quiet {i_s_axil_* i_m_axi_*}]
set AXI_OUTPUTS [get_ports -quiet {o_s_axil_* o_m_axi_*}]

if {[llength $AXI_INPUTS] > 0} {
    group_path -name AXI_INPUTS -from $AXI_INPUTS
    
    set INPUT_DELAY_MAX  [expr {0.30 * $SYS_PERIOD}]
    set INPUT_DELAY_MIN  [expr {0.25 * $SYS_PERIOD}]
    
    set_input_delay -clock SYS_CLK -max $INPUT_DELAY_MAX $AXI_INPUTS
    set_input_delay -clock SYS_CLK -min $INPUT_DELAY_MIN $AXI_INPUTS
    
    set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X $AXI_INPUTS
    set_input_transition 0.15 $AXI_INPUTS
}

if {[llength $AXI_OUTPUTS] > 0} {
    group_path -name AXI_OUTPUTS -to $AXI_OUTPUTS

    set OUTPUT_DELAY_MAX [expr {0.20 * $SYS_PERIOD}]
    set OUTPUT_DELAY_MIN 0.00

    set_output_delay -clock SYS_CLK -max $OUTPUT_DELAY_MAX $AXI_OUTPUTS
    set_output_delay -clock SYS_CLK -min $OUTPUT_DELAY_MIN $AXI_OUTPUTS

    set_load 0.03 $AXI_OUTPUTS
}