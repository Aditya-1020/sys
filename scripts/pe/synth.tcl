yosys -import
set libfile $::env(TT_SYNTH_LIB)

read_verilog verilog_sv2v/pe.v
synth -top pe -flatten
opt -full
clockgate -min_net_size 2 -pos sky130_fd_sc_hd__dlclkp_2 GATE:CLK:GCLK
dfflibmap -liberty $libfile
abc -liberty $libfile -D 8000
opt_clean -purge
stat -liberty $libfile
write_verilog -noattr build/pe_synth.v