read_liberty $env(TT_STA_LIB)
read_verilog build/systolic_array_synth.v
link_design systolic_array
read_sdc constraints/systolic_array.sdc
report_checks -path_delay max -format full
exit