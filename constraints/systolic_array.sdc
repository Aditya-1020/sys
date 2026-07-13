set clock_port "clk"
set reset_port "rstn"

create_clock -name SYS_CLK -period 10.0 [get_ports $clock_port]

set clocks [get_clocks SYS_CLK]
set resets [get_ports $reset_port]

set_clock_uncertainty 0.25 $clocks

set csr_in [get_ports {csr_wr csr_rd csr_addr csr_wdata}]
set_input_delay 1.0 -max -clock $clocks $csr_in
set_input_delay 1.0 -min -clock $clocks $csr_in

# ignore timing on reset port to registers (async reset)
set_false_path -from $resets -to [all_registers]

set_output_delay 1.0 -max -clock $clocks [get_ports {csr_rdata csr_rvalid}]
