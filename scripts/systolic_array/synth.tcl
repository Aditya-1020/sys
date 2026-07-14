yosys -import
set libfile $::env(TT_STA_LIB)
read_verilog verilog_sv2v/pe.v verilog_sv2v/systolic_array.v
synth -top systolic_array
dfflibmap -liberty $libfile
abc -liberty $libfile
opt -full -fast
opt_clean
opt_merge
stat
write_verilog -noattr build/systolic_array_synth.v
