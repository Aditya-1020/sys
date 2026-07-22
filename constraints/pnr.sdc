source [file join [file dirname [info script]] base.sdc]
set_clock_uncertainty -setup 0.25 [get_clocks SYS_CLK]
set_clock_uncertainty -hold 0.10 [get_clocks SYS_CLK]

set_clock_uncertainty -setup 0.50 [get_clocks SPI_CLK]
set_clock_uncertainty -hold 0.10 [get_clocks SPI_CLK]

set_clock_transition 0.15 [all_clocks]

