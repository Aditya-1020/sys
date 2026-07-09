read_liberty $env(TT_STA_LIB)
read_verilog build/pe_synth.v
link_design pe
read_sdc constraints/pe.sdc
report_checks -path_delay max -format full
exit