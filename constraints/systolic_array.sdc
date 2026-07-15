create_clock -name SYS_CLK -period 13.33 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks SYS_CLK]

# data input list except the clock and reset pins
set data_inputs {}
foreach port [all_inputs -no_clocks] {
    if {[get_full_name $port] ne "rstn"} {
        lappend data_inputs $port
    }
}

set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y $data_inputs
set_load 0.05 [all_outputs]

set_input_delay  1.0 -clock SYS_CLK $data_inputs
set_output_delay 1.0 -clock SYS_CLK [all_outputs]

set_false_path -from [get_ports rstn]

set_max_transition 0.75 [current_design]
set_max_fanout 12 [current_design]