read_liberty $env(TT_STA_LIB)
read_liberty $env(STA_SRAM_LIB)

read_verilog build/top_synth.v
link_design top
read_sdc constraints/top.sdc

set st_net [get_nets {u_accel.u_array.current_state[*]}]
set st_ff  [get_cells -of_objects [get_pins -of_objects $st_net -filter {direction == output}]]

# group_path -name in2reg  -from [all_inputs]
# group_path -name reg2out -to [all_outputs]
# group_path -name reg2reg -from [all_registers] -to [all_registers]

check_setup

# scoreboard
report_worst_slack -max
report_worst_slack -min
report_tns

# report_checks -path_delay min_max -format end -slack_max 0 -group_path_count 5

report_checks -path_delay max -format full -fields {slew cap fanout input_pins} -digits 3
report_checks -from $st_ff -to $st_ff -path_delay max -format full -fields {slew cap fanout} -digits 3
report_checks -to $st_ff -path_delay max -format full -fields {slew cap fanout} -digits 3
report_checks -from $st_ff -path_delay max -format full -fields {slew cap fanout} -digits 3