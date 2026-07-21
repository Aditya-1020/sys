yosys -import
set libfile $::env(TT_SYNTH_LIB)
set sram_lib $::env(STA_SRAM_LIB)

# sram macro comes in as a liberty blackbox, not the behavioral model
read_liberty -lib $sram_lib
read_verilog verilog_sv2v/*.v
synth -top top -flatten
opt -full
dfflibmap -liberty $libfile
abc -liberty $libfile -D 8000
opt_clean -purge
stat -liberty $libfile
write_verilog -noattr build/top_synth.v
