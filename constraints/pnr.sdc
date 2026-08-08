source [file join [file dirname [info script]] base.sdc]

set_clock_uncertainty -setup 0.30 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.10 [get_clocks SYS_CLK]

set_timing_derate -early 0.98
set_timing_derate -late  1.02
