set libdir /home/link/gf/sky130/libs.ref
read_verilog -sv systolic_array_2x2.sv
synth -top systolic_array_2x2
dfflibmap -liberty $libdir/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
abc -liberty $libdir/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
opt -full -fast
opt_reduce
opt_clean
opt_merge
stat
write_verilog -noattr synth_out_systolic_array_2x2.v