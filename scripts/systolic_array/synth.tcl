yosys -import
set libfile $::env(TT_SYNTH_LIB)

read_verilog verilog_sv2v/pe.v verilog_sv2v/systolic_array.v
synth -top systolic_array -flatten
opt -full
dfflibmap -liberty $libfile
abc -liberty $libfile -D 8000
opt_clean -purge
stat -liberty $libfile
write_verilog -noattr build/systolic_array_synth.v