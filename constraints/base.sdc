set SYS_PERIOD [expr {[info exists ::env(CLOCK_PERIOD)] ? $::env(CLOCK_PERIOD) : 10.0}]

create_clock -name SYS_CLK -period $SYS_PERIOD [get_ports clk]

set_clock_transition 0.15 [get_clocks SYS_CLK]

set_clock_uncertainty -setup 0.25 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.08 [get_clocks SYS_CLK]

set_timing_derate -early 0.99
set_timing_derate -late  1.01

set_max_fanout 21 [current_design]

set_false_path -from [get_ports rstn]

set_false_path -to [get_pins {u_sram.u_m0/rstb u_sram.u_m1/rstb}]

# setting a myticycle path for sram dout exceeded 5ns at ss100
set _sram_dout [get_pins -quiet {u_sram.u_m0/dout[*] u_sram.u_m1/dout[*]}]
if {[llength $_sram_dout] > 0} {
    set_multicycle_path 2 -setup -through $_sram_dout
    set_multicycle_path 1 -hold  -through $_sram_dout
}
unset _sram_dout

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X [get_ports rstn]

set AXI_INPUTS  [get_ports -quiet {i_s_axil_* i_m_axi_*}]
set AXI_OUTPUTS [get_ports -quiet {o_s_axil_* o_m_axi_*}]

if {[llength $AXI_INPUTS] > 0} {
    group_path -name AXI_INPUTS -from $AXI_INPUTS

    set_input_delay -clock SYS_CLK -max [expr {0.30 * $SYS_PERIOD}] $AXI_INPUTS
    set_input_delay -clock SYS_CLK -min [expr {0.25 * $SYS_PERIOD}] $AXI_INPUTS

    set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X $AXI_INPUTS
}

if {[llength $AXI_OUTPUTS] > 0} {
    group_path -name AXI_OUTPUTS -to $AXI_OUTPUTS

    set_output_delay -clock SYS_CLK -max [expr {0.20 * $SYS_PERIOD}] $AXI_OUTPUTS
    set_output_delay -clock SYS_CLK -min 0.00 $AXI_OUTPUTS

    set_load 0.03 $AXI_OUTPUTS
}
