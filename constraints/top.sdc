create_clock -name SYS_CLK -period 5.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks SYS_CLK]

create_clock -name SPI_CLK -period 10.0 [get_ports spi_sclk]
set_clock_uncertainty 0.50 [get_clocks SPI_CLK]

set_clock_groups -asynchronous -group {SYS_CLK} -group {SPI_CLK}

set_input_delay  2.0 -clock SPI_CLK [get_ports spi_mosi]
set_output_delay 2.0 -clock SPI_CLK [get_ports spi_miso]

set_false_path -from [get_ports {spi_cs_n rstn}]

set_output_delay 1.0 -clock SYS_CLK [get_ports o_irq]
set_load 0.03 [all_outputs]

set_max_fanout 16 [current_design]
set_max_transition 0.75 [current_design]