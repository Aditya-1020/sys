set SYS_PERIOD 12.0
set SPI_PERIOD 10.0

create_clock -name SYS_CLK -period $SYS_PERIOD [get_ports clk]
create_clock -name SPI_CLK -period $SPI_PERIOD [get_ports spi_sclk]

set_clock_groups -asynchronous -group {SYS_CLK} -group {SPI_CLK}

set_false_path -from [get_ports rstn]
set_false_path -from [get_ports spi_cs_n]

set_input_delay  -clock SPI_CLK -max 2.0 [get_ports spi_mosi]
set_input_delay  -clock SPI_CLK -min 0.5 [get_ports spi_mosi]

set_output_delay -clock SPI_CLK -max 2.0 [get_ports spi_miso]
set_output_delay -clock SPI_CLK -min 0.0 [get_ports spi_miso]

set_output_delay -clock SYS_CLK -max 1.0 [get_ports o_irq]
set_output_delay -clock SYS_CLK -min 0.0 [get_ports o_irq]

set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [get_ports {spi_mosi spi_cs_n rstn}]
set_load 0.03 [all_outputs]

set_max_transition 0.75 [current_design]
set_max_fanout 16 [current_design]

