source [file join [file dirname [info script]] base.sdc]

set_propagated_clock [get_clocks SYS_CLK]

set_clock_uncertainty -setup 0.10 [get_clocks SYS_CLK]
set_clock_uncertainty -hold  0.05 [get_clocks SYS_CLK]

set_timing_derate -early 0.95
set_timing_derate -late  1.05

set_max_transition 0.60 [current_design]
set_max_fanout 16 [current_design]

set SRAM_DOUT_PINS [get_pins -quiet {u_sram/u_m*/dout*}]

if {[llength $SRAM_DOUT_PINS] > 0} {
    set_max_capacitance 0.025 $SRAM_DOUT_PINS
} else {
    puts "WARN: signoff.sdc: SRAM dout pins not found."
}
