set clock_port "clk"
set reset_port "rstn"

create_clock -name SYS_CLK -period 10.0 [get_ports $clock_port]

set clocks [get_clocks SYS_CLK]
set resets [get_ports $reset_port]
set clock_input [get_ports $clock_port]

set_clock_uncertainty 0.25 $clocks

set_input_delay 1.0 -max -clock $clocks [get_ports {i_ld_valid i_ld_a i_pe_sign_en i_result_ready}]
set_input_delay 1.0 -min -clock $clocks [get_ports {i_ld_valid i_ld_a i_pe_sign_en i_result_ready}]

# ignore timing on reset port to registers (async reset)
set_false_path -from $resets -to [all_registers]

set_output_delay 1.0 -max -clock $clocks [get_ports {o_ld_ready o_result_valid o_result_data}]

report_checks -path_delay max -format full_clock_expanded -digits 3 
report_checks -path_delay min -digits 3
report_wns
report_tns
