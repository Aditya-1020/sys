create_clock -period 10.0 [get_ports clk]

set_input_delay 1.0 -clock clk [get_ports {acc_en_i input_i weight_i top_input_i}]
set_false_path -from [get_ports rstn] -to [all_registers]
set_output_delay 1.0 -clock clk [get_ports output_o]

# report_net _1087_
report_checks -path_delay max -digits 3
report_wns
report_tns