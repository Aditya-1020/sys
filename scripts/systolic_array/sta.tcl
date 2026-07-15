read_liberty $env(TT_STA_LIB)
read_verilog build/systolic_array_synth.v
link_design systolic_array
read_sdc constraints/systolic_array.sdc

group_path -name in2reg  -from [all_inputs]
group_path -name reg2out -to [all_outputs]
group_path -name reg2reg -from [all_registers] -to [all_registers]

check_setup

# scoreboard
report_worst_slack -max
report_worst_slack -min
report_tns
report_check_types -max_transition -max_fanout -violators

# violations only, compact
report_checks -path_delay min_max -format end -slack_max 0 -group_count 5

# then zoom into ONE path with full detail + the fields that explain *why* it's slow
report_checks -path_delay max -format full -fields {slew cap fanout input_pins} -digits 3