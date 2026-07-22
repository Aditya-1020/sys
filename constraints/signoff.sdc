source [file join [file dirname [info script]] base.sdc]

set_propagated_clock [all_clocks]

set_clock_uncertainty -setup 0.10 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.05 [get_clocks SYS_CLK]

set_clock_uncertainty -setup 0.25 [get_clocks SPI_CLK]
set_clock_uncertainty -hold  0.05 [get_clocks SPI_CLK]

set_timing_derate -early 0.95
set_timing_derate -late 1.05
