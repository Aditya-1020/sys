source [file join [file dirname [info script]] base.sdc]

set_clock_uncertainty -setup 0.40 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.15 [get_clocks SYS_CLK]

set_clock_uncertainty -setup 0.60 [get_clocks SPI_CLK]
set_clock_uncertainty -hold  0.15 [get_clocks SPI_CLK]

set_clock_transition 0.15 [all_clocks]

set_timing_derate -early 0.95
set_timing_derate -late  1.05

set sram_dout1 [get_pins -quiet {u_accel.u_in_fifo.sram/dout1[*]}]

if {[llength $sram_dout1] > 0} {
	set_max_capacitance 0.025 $sram_dout1
} else {
	puts "sram dout1 pins not found"
}