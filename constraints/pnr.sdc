source [file join [file dirname [info script]] base.sdc]

set_clock_uncertainty -setup 0.35 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.15 [get_clocks SYS_CLK]

set_timing_derate -early 0.95
set_timing_derate -late  1.05

set_max_transition 0.60 [current_design]
set_max_fanout 16 [current_design]

set AXI_INPUT_PORTS  [get_ports -quiet {i_s_axil_* i_m_axi_*}]
set AXI_OUTPUT_PORTS [get_ports -quiet {o_s_axil_* o_m_axi_*}]

if {[llength $AXI_INPUT_PORTS] > 0} {
    group_path -name AXI_INPUTS -from $AXI_INPUT_PORTS
}

if {[llength $AXI_OUTPUT_PORTS] > 0} {
    group_path -name AXI_OUTPUTS -to $AXI_OUTPUT_PORTS
}
