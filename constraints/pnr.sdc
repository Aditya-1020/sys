source [file join [file dirname [info script]] base.sdc]

set_clock_uncertainty -setup 0.30 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.10 [get_clocks SYS_CLK]

set_timing_derate -early 0.98
set_timing_derate -late  1.02

set_max_transition 0.75 [current_design]
set_max_fanout 10 [current_design]

set AXI_INPUTS  [get_ports -quiet {i_s_axil_* i_m_axi_*}]
set AXI_OUTPUTS [get_ports -quiet {o_s_axil_* o_m_axi_*}]

if {[llength $AXI_INPUTS] > 0} {
    group_path -name AXI_INPUTS -from $AXI_INPUTS
}

if {[llength $AXI_OUTPUTS] > 0} {
    group_path -name AXI_OUTPUTS -to $AXI_OUTPUTS
}