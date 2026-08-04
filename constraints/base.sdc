set SYS_PERIOD 10.0

create_clock -name SYS_CLK -period $SYS_PERIOD [get_ports clk]
set_clock_transition 0.15 [get_clocks SYS_CLK]

set RST_PORT [get_ports rstn]
set RST_SYNC_CELLS [get_cells -quiet -hier u_rsync*]


if {[llength $RST_SYNC_CELLS] > 0} {
    set_false_path -from $RST_PORT -to $RST_SYNC_CELLS
} else {
    set_false_path -from $RST_PORT
}

set DATA_INPUTS  [get_ports -quiet {i_s_axil_* i_m_axi_*}]
set DATA_OUTPUTS [get_ports -quiet {o_s_axil_* o_m_axi_*}]

set INPUT_DELAY_MAX  [expr {0.20 * $SYS_PERIOD}]
set INPUT_DELAY_MIN  [expr {0.05 * $SYS_PERIOD}]

set OUTPUT_DELAY_MAX [expr {0.20 * $SYS_PERIOD}]
set OUTPUT_DELAY_MIN 0.00

set_input_delay  -clock SYS_CLK -max $INPUT_DELAY_MAX  $DATA_INPUTS
set_input_delay  -clock SYS_CLK -min $INPUT_DELAY_MIN  $DATA_INPUTS

set_output_delay -clock SYS_CLK -max $OUTPUT_DELAY_MAX $DATA_OUTPUTS
set_output_delay -clock SYS_CLK -min $OUTPUT_DELAY_MIN $DATA_OUTPUTS

set INPUT_DRIVE_CELL sky130_fd_sc_hd__buf_4
set INPUT_DRIVE_PIN X

set_driving_cell -lib_cell $INPUT_DRIVE_CELL -pin $INPUT_DRIVE_PIN $DATA_INPUTS
set_driving_cell -lib_cell $INPUT_DRIVE_CELL -pin $INPUT_DRIVE_PIN $RST_PORT

set_input_transition 0.10 [get_ports clk]
set_input_transition 0.15 $DATA_INPUTS
set_input_transition 0.15 $RST_PORT

set_load 0.03 $DATA_OUTPUTS

set_max_capacitance 0.035 $DATA_OUTPUTS

set_max_transition 0.75 [current_design]
set_max_fanout 16 [current_design]

set SRAM_DOUT_PINS [get_pins -quiet {u_sram/u_m*/dout*}]

if {[llength $SRAM_DOUT_PINS] > 0} {
    set_max_capacitance 0.025 $SRAM_DOUT_PINS
} else {
    puts "INFO: base.sdc: SRAM dout pins not found."
}