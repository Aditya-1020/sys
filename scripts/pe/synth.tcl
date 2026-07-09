yosys -import
set libfile $::env(TT_STA_LIB)
read_verilog verilog_sv2v/pe.v
synth -top pe
dfflibmap -liberty $libfile
abc -liberty $libfile
opt -full -fast
opt_reduce
opt_clean
opt_merge
stat
write_verilog -noattr build/pe_synth.v