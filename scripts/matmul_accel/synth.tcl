yosys -import
set libfile $::env(TT_STA_LIB)
read_verilog verilog_sv2v/pe.v verilog_sv2v/systolic_array.v verilog_sv2v/matmul_accel.v
synth -top matmul_accel
dfflibmap -liberty $libfile
abc -liberty $libfile
opt -full -fast
opt_clean
opt_merge
stat
write_verilog -noattr build/matmul_accel_synth.v
