create_clock -name SYS_CLK -period 10.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks SYS_CLK]

set async_ins {spi_sclk spi_cs_n spi_mosi rstn}

set_false_path -from [get_ports $async_ins]

set_output_delay 1.0 -clock SYS_CLK [all_outputs]
set_load 0.03 [all_outputs]

set_max_fanout 16 [current_design]
set_max_transition 0.75 [current_design]

