source [file join [file dirname [info script]] base.sdc]

set_propagated_clock [get_clocks SYS_CLK]

set_clock_uncertainty -setup 0.10 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.05 [get_clocks SYS_CLK]

set_max_transition 1.50 [current_design]
