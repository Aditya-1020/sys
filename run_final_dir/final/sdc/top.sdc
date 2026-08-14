###############################################################################
# Created by write_sdc
###############################################################################
current_design top
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name SYS_CLK -period 10.0000 [get_ports {clk}]
set_clock_transition 0.1500 [get_clocks {SYS_CLK}]
set_clock_uncertainty -setup 0.3000 SYS_CLK
set_clock_uncertainty -hold 0.1000 SYS_CLK
set_propagated_clock [get_clocks {SYS_CLK}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_arready}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_arready}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_awready}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_awready}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_bresp[0]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_bresp[0]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_bresp[1]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_bresp[1]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_bvalid}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_bvalid}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[0]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[0]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[10]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[10]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[11]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[11]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[12]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[12]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[13]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[13]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[14]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[14]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[15]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[15]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[16]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[16]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[17]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[17]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[18]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[18]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[19]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[19]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[1]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[1]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[20]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[20]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[21]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[21]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[22]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[22]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[23]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[23]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[24]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[24]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[25]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[25]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[26]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[26]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[27]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[27]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[28]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[28]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[29]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[29]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[2]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[2]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[30]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[30]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[31]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[31]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[3]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[3]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[4]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[4]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[5]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[5]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[6]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[6]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[7]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[7]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[8]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[8]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rdata[9]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rdata[9]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rlast}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rlast}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rresp[0]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rresp[0]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rresp[1]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rresp[1]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_rvalid}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_rvalid}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_m_axi_wready}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_m_axi_wready}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[0]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[0]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[1]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[1]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[2]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[2]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[3]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[3]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[4]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[4]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[5]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[5]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[6]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[6]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_araddr[7]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_araddr[7]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_arvalid}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_arvalid}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[0]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[0]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[1]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[1]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[2]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[2]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[3]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[3]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[4]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[4]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[5]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[5]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[6]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[6]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awaddr[7]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awaddr[7]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_awvalid}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_awvalid}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_bready}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_bready}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_rready}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_rready}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[0]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[0]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[10]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[10]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[11]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[11]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[12]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[12]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[13]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[13]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[14]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[14]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[15]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[15]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[16]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[16]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[17]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[17]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[18]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[18]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[19]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[19]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[1]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[1]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[20]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[20]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[21]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[21]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[22]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[22]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[23]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[23]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[24]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[24]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[25]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[25]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[26]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[26]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[27]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[27]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[28]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[28]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[29]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[29]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[2]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[2]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[30]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[30]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[31]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[31]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[3]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[3]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[4]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[4]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[5]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[5]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[6]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[6]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[7]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[7]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[8]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[8]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wdata[9]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wdata[9]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wstrb[0]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wstrb[0]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wstrb[1]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wstrb[1]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wstrb[2]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wstrb[2]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wstrb[3]}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wstrb[3]}]
set_input_delay 2.5000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {i_s_axil_wvalid}]
set_input_delay 3.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {i_s_axil_wvalid}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[0]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[0]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[10]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[10]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[11]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[11]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[12]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[12]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[13]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[13]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[14]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[14]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[15]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[15]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[16]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[16]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[17]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[17]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[18]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[18]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[19]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[19]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[1]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[1]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[20]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[20]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[21]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[21]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[22]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[22]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[23]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[23]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[24]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[24]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[25]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[25]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[26]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[26]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[27]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[27]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[28]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[28]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[29]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[29]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[2]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[2]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[30]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[30]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[31]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[31]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[3]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[3]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[4]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[4]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[5]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[5]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[6]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[6]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[7]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[7]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[8]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[8]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_araddr[9]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_araddr[9]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[0]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[0]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[1]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[1]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[2]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[2]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[3]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[3]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[4]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[4]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[5]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[5]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[6]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[6]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arlen[7]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arlen[7]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_arvalid}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_arvalid}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[0]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[0]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[10]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[10]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[11]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[11]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[12]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[12]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[13]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[13]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[14]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[14]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[15]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[15]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[16]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[16]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[17]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[17]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[18]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[18]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[19]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[19]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[1]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[1]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[20]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[20]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[21]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[21]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[22]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[22]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[23]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[23]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[24]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[24]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[25]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[25]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[26]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[26]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[27]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[27]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[28]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[28]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[29]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[29]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[2]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[2]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[30]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[30]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[31]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[31]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[3]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[3]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[4]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[4]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[5]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[5]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[6]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[6]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[7]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[7]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[8]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[8]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awaddr[9]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awaddr[9]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_awvalid}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_awvalid}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_bready}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_bready}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_rready}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_rready}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[0]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[0]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[10]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[10]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[11]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[11]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[12]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[12]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[13]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[13]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[14]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[14]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[15]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[15]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[16]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[16]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[17]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[17]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[18]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[18]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[19]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[19]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[1]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[1]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[20]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[20]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[21]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[21]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[22]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[22]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[23]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[23]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[24]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[24]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[25]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[25]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[26]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[26]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[27]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[27]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[28]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[28]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[29]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[29]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[2]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[2]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[30]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[30]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[31]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[31]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[3]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[3]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[4]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[4]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[5]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[5]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[6]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[6]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[7]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[7]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[8]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[8]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wdata[9]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wdata[9]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wlast}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wlast}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_m_axi_wvalid}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_m_axi_wvalid}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_arready}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_arready}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_awready}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_awready}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_bresp[0]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_bresp[0]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_bresp[1]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_bresp[1]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_bvalid}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_bvalid}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[0]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[0]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[10]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[10]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[11]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[11]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[12]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[12]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[13]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[13]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[14]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[14]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[15]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[15]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[16]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[16]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[17]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[17]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[18]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[18]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[19]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[19]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[1]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[1]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[20]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[20]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[21]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[21]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[22]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[22]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[23]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[23]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[24]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[24]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[25]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[25]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[26]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[26]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[27]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[27]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[28]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[28]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[29]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[29]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[2]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[2]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[30]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[30]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[31]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[31]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[3]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[3]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[4]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[4]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[5]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[5]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[6]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[6]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[7]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[7]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[8]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[8]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rdata[9]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rdata[9]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rresp[0]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rresp[0]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rresp[1]}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rresp[1]}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_rvalid}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_rvalid}]
set_output_delay 0.0000 -clock [get_clocks {SYS_CLK}] -min -add_delay [get_ports {o_s_axil_wready}]
set_output_delay 2.0000 -clock [get_clocks {SYS_CLK}] -max -add_delay [get_ports {o_s_axil_wready}]
group_path -name AXI_INPUTS\
    -from [list [get_ports {i_m_axi_arready}]\
           [get_ports {i_m_axi_awready}]\
           [get_ports {i_m_axi_bresp[0]}]\
           [get_ports {i_m_axi_bresp[1]}]\
           [get_ports {i_m_axi_bvalid}]\
           [get_ports {i_m_axi_rdata[0]}]\
           [get_ports {i_m_axi_rdata[10]}]\
           [get_ports {i_m_axi_rdata[11]}]\
           [get_ports {i_m_axi_rdata[12]}]\
           [get_ports {i_m_axi_rdata[13]}]\
           [get_ports {i_m_axi_rdata[14]}]\
           [get_ports {i_m_axi_rdata[15]}]\
           [get_ports {i_m_axi_rdata[16]}]\
           [get_ports {i_m_axi_rdata[17]}]\
           [get_ports {i_m_axi_rdata[18]}]\
           [get_ports {i_m_axi_rdata[19]}]\
           [get_ports {i_m_axi_rdata[1]}]\
           [get_ports {i_m_axi_rdata[20]}]\
           [get_ports {i_m_axi_rdata[21]}]\
           [get_ports {i_m_axi_rdata[22]}]\
           [get_ports {i_m_axi_rdata[23]}]\
           [get_ports {i_m_axi_rdata[24]}]\
           [get_ports {i_m_axi_rdata[25]}]\
           [get_ports {i_m_axi_rdata[26]}]\
           [get_ports {i_m_axi_rdata[27]}]\
           [get_ports {i_m_axi_rdata[28]}]\
           [get_ports {i_m_axi_rdata[29]}]\
           [get_ports {i_m_axi_rdata[2]}]\
           [get_ports {i_m_axi_rdata[30]}]\
           [get_ports {i_m_axi_rdata[31]}]\
           [get_ports {i_m_axi_rdata[3]}]\
           [get_ports {i_m_axi_rdata[4]}]\
           [get_ports {i_m_axi_rdata[5]}]\
           [get_ports {i_m_axi_rdata[6]}]\
           [get_ports {i_m_axi_rdata[7]}]\
           [get_ports {i_m_axi_rdata[8]}]\
           [get_ports {i_m_axi_rdata[9]}]\
           [get_ports {i_m_axi_rlast}]\
           [get_ports {i_m_axi_rresp[0]}]\
           [get_ports {i_m_axi_rresp[1]}]\
           [get_ports {i_m_axi_rvalid}]\
           [get_ports {i_m_axi_wready}]\
           [get_ports {i_s_axil_araddr[0]}]\
           [get_ports {i_s_axil_araddr[1]}]\
           [get_ports {i_s_axil_araddr[2]}]\
           [get_ports {i_s_axil_araddr[3]}]\
           [get_ports {i_s_axil_araddr[4]}]\
           [get_ports {i_s_axil_araddr[5]}]\
           [get_ports {i_s_axil_araddr[6]}]\
           [get_ports {i_s_axil_araddr[7]}]\
           [get_ports {i_s_axil_arvalid}]\
           [get_ports {i_s_axil_awaddr[0]}]\
           [get_ports {i_s_axil_awaddr[1]}]\
           [get_ports {i_s_axil_awaddr[2]}]\
           [get_ports {i_s_axil_awaddr[3]}]\
           [get_ports {i_s_axil_awaddr[4]}]\
           [get_ports {i_s_axil_awaddr[5]}]\
           [get_ports {i_s_axil_awaddr[6]}]\
           [get_ports {i_s_axil_awaddr[7]}]\
           [get_ports {i_s_axil_awvalid}]\
           [get_ports {i_s_axil_bready}]\
           [get_ports {i_s_axil_rready}]\
           [get_ports {i_s_axil_wdata[0]}]\
           [get_ports {i_s_axil_wdata[10]}]\
           [get_ports {i_s_axil_wdata[11]}]\
           [get_ports {i_s_axil_wdata[12]}]\
           [get_ports {i_s_axil_wdata[13]}]\
           [get_ports {i_s_axil_wdata[14]}]\
           [get_ports {i_s_axil_wdata[15]}]\
           [get_ports {i_s_axil_wdata[16]}]\
           [get_ports {i_s_axil_wdata[17]}]\
           [get_ports {i_s_axil_wdata[18]}]\
           [get_ports {i_s_axil_wdata[19]}]\
           [get_ports {i_s_axil_wdata[1]}]\
           [get_ports {i_s_axil_wdata[20]}]\
           [get_ports {i_s_axil_wdata[21]}]\
           [get_ports {i_s_axil_wdata[22]}]\
           [get_ports {i_s_axil_wdata[23]}]\
           [get_ports {i_s_axil_wdata[24]}]\
           [get_ports {i_s_axil_wdata[25]}]\
           [get_ports {i_s_axil_wdata[26]}]\
           [get_ports {i_s_axil_wdata[27]}]\
           [get_ports {i_s_axil_wdata[28]}]\
           [get_ports {i_s_axil_wdata[29]}]\
           [get_ports {i_s_axil_wdata[2]}]\
           [get_ports {i_s_axil_wdata[30]}]\
           [get_ports {i_s_axil_wdata[31]}]\
           [get_ports {i_s_axil_wdata[3]}]\
           [get_ports {i_s_axil_wdata[4]}]\
           [get_ports {i_s_axil_wdata[5]}]\
           [get_ports {i_s_axil_wdata[6]}]\
           [get_ports {i_s_axil_wdata[7]}]\
           [get_ports {i_s_axil_wdata[8]}]\
           [get_ports {i_s_axil_wdata[9]}]\
           [get_ports {i_s_axil_wstrb[0]}]\
           [get_ports {i_s_axil_wstrb[1]}]\
           [get_ports {i_s_axil_wstrb[2]}]\
           [get_ports {i_s_axil_wstrb[3]}]\
           [get_ports {i_s_axil_wvalid}]]
group_path -name AXI_OUTPUTS\
    -to [list [get_ports {o_m_axi_araddr[0]}]\
           [get_ports {o_m_axi_araddr[10]}]\
           [get_ports {o_m_axi_araddr[11]}]\
           [get_ports {o_m_axi_araddr[12]}]\
           [get_ports {o_m_axi_araddr[13]}]\
           [get_ports {o_m_axi_araddr[14]}]\
           [get_ports {o_m_axi_araddr[15]}]\
           [get_ports {o_m_axi_araddr[16]}]\
           [get_ports {o_m_axi_araddr[17]}]\
           [get_ports {o_m_axi_araddr[18]}]\
           [get_ports {o_m_axi_araddr[19]}]\
           [get_ports {o_m_axi_araddr[1]}]\
           [get_ports {o_m_axi_araddr[20]}]\
           [get_ports {o_m_axi_araddr[21]}]\
           [get_ports {o_m_axi_araddr[22]}]\
           [get_ports {o_m_axi_araddr[23]}]\
           [get_ports {o_m_axi_araddr[24]}]\
           [get_ports {o_m_axi_araddr[25]}]\
           [get_ports {o_m_axi_araddr[26]}]\
           [get_ports {o_m_axi_araddr[27]}]\
           [get_ports {o_m_axi_araddr[28]}]\
           [get_ports {o_m_axi_araddr[29]}]\
           [get_ports {o_m_axi_araddr[2]}]\
           [get_ports {o_m_axi_araddr[30]}]\
           [get_ports {o_m_axi_araddr[31]}]\
           [get_ports {o_m_axi_araddr[3]}]\
           [get_ports {o_m_axi_araddr[4]}]\
           [get_ports {o_m_axi_araddr[5]}]\
           [get_ports {o_m_axi_araddr[6]}]\
           [get_ports {o_m_axi_araddr[7]}]\
           [get_ports {o_m_axi_araddr[8]}]\
           [get_ports {o_m_axi_araddr[9]}]\
           [get_ports {o_m_axi_arlen[0]}]\
           [get_ports {o_m_axi_arlen[1]}]\
           [get_ports {o_m_axi_arlen[2]}]\
           [get_ports {o_m_axi_arlen[3]}]\
           [get_ports {o_m_axi_arlen[4]}]\
           [get_ports {o_m_axi_arlen[5]}]\
           [get_ports {o_m_axi_arlen[6]}]\
           [get_ports {o_m_axi_arlen[7]}]\
           [get_ports {o_m_axi_arvalid}]\
           [get_ports {o_m_axi_awaddr[0]}]\
           [get_ports {o_m_axi_awaddr[10]}]\
           [get_ports {o_m_axi_awaddr[11]}]\
           [get_ports {o_m_axi_awaddr[12]}]\
           [get_ports {o_m_axi_awaddr[13]}]\
           [get_ports {o_m_axi_awaddr[14]}]\
           [get_ports {o_m_axi_awaddr[15]}]\
           [get_ports {o_m_axi_awaddr[16]}]\
           [get_ports {o_m_axi_awaddr[17]}]\
           [get_ports {o_m_axi_awaddr[18]}]\
           [get_ports {o_m_axi_awaddr[19]}]\
           [get_ports {o_m_axi_awaddr[1]}]\
           [get_ports {o_m_axi_awaddr[20]}]\
           [get_ports {o_m_axi_awaddr[21]}]\
           [get_ports {o_m_axi_awaddr[22]}]\
           [get_ports {o_m_axi_awaddr[23]}]\
           [get_ports {o_m_axi_awaddr[24]}]\
           [get_ports {o_m_axi_awaddr[25]}]\
           [get_ports {o_m_axi_awaddr[26]}]\
           [get_ports {o_m_axi_awaddr[27]}]\
           [get_ports {o_m_axi_awaddr[28]}]\
           [get_ports {o_m_axi_awaddr[29]}]\
           [get_ports {o_m_axi_awaddr[2]}]\
           [get_ports {o_m_axi_awaddr[30]}]\
           [get_ports {o_m_axi_awaddr[31]}]\
           [get_ports {o_m_axi_awaddr[3]}]\
           [get_ports {o_m_axi_awaddr[4]}]\
           [get_ports {o_m_axi_awaddr[5]}]\
           [get_ports {o_m_axi_awaddr[6]}]\
           [get_ports {o_m_axi_awaddr[7]}]\
           [get_ports {o_m_axi_awaddr[8]}]\
           [get_ports {o_m_axi_awaddr[9]}]\
           [get_ports {o_m_axi_awvalid}]\
           [get_ports {o_m_axi_bready}]\
           [get_ports {o_m_axi_rready}]\
           [get_ports {o_m_axi_wdata[0]}]\
           [get_ports {o_m_axi_wdata[10]}]\
           [get_ports {o_m_axi_wdata[11]}]\
           [get_ports {o_m_axi_wdata[12]}]\
           [get_ports {o_m_axi_wdata[13]}]\
           [get_ports {o_m_axi_wdata[14]}]\
           [get_ports {o_m_axi_wdata[15]}]\
           [get_ports {o_m_axi_wdata[16]}]\
           [get_ports {o_m_axi_wdata[17]}]\
           [get_ports {o_m_axi_wdata[18]}]\
           [get_ports {o_m_axi_wdata[19]}]\
           [get_ports {o_m_axi_wdata[1]}]\
           [get_ports {o_m_axi_wdata[20]}]\
           [get_ports {o_m_axi_wdata[21]}]\
           [get_ports {o_m_axi_wdata[22]}]\
           [get_ports {o_m_axi_wdata[23]}]\
           [get_ports {o_m_axi_wdata[24]}]\
           [get_ports {o_m_axi_wdata[25]}]\
           [get_ports {o_m_axi_wdata[26]}]\
           [get_ports {o_m_axi_wdata[27]}]\
           [get_ports {o_m_axi_wdata[28]}]\
           [get_ports {o_m_axi_wdata[29]}]\
           [get_ports {o_m_axi_wdata[2]}]\
           [get_ports {o_m_axi_wdata[30]}]\
           [get_ports {o_m_axi_wdata[31]}]\
           [get_ports {o_m_axi_wdata[3]}]\
           [get_ports {o_m_axi_wdata[4]}]\
           [get_ports {o_m_axi_wdata[5]}]\
           [get_ports {o_m_axi_wdata[6]}]\
           [get_ports {o_m_axi_wdata[7]}]\
           [get_ports {o_m_axi_wdata[8]}]\
           [get_ports {o_m_axi_wdata[9]}]\
           [get_ports {o_m_axi_wlast}]\
           [get_ports {o_m_axi_wvalid}]\
           [get_ports {o_s_axil_arready}]\
           [get_ports {o_s_axil_awready}]\
           [get_ports {o_s_axil_bresp[0]}]\
           [get_ports {o_s_axil_bresp[1]}]\
           [get_ports {o_s_axil_bvalid}]\
           [get_ports {o_s_axil_rdata[0]}]\
           [get_ports {o_s_axil_rdata[10]}]\
           [get_ports {o_s_axil_rdata[11]}]\
           [get_ports {o_s_axil_rdata[12]}]\
           [get_ports {o_s_axil_rdata[13]}]\
           [get_ports {o_s_axil_rdata[14]}]\
           [get_ports {o_s_axil_rdata[15]}]\
           [get_ports {o_s_axil_rdata[16]}]\
           [get_ports {o_s_axil_rdata[17]}]\
           [get_ports {o_s_axil_rdata[18]}]\
           [get_ports {o_s_axil_rdata[19]}]\
           [get_ports {o_s_axil_rdata[1]}]\
           [get_ports {o_s_axil_rdata[20]}]\
           [get_ports {o_s_axil_rdata[21]}]\
           [get_ports {o_s_axil_rdata[22]}]\
           [get_ports {o_s_axil_rdata[23]}]\
           [get_ports {o_s_axil_rdata[24]}]\
           [get_ports {o_s_axil_rdata[25]}]\
           [get_ports {o_s_axil_rdata[26]}]\
           [get_ports {o_s_axil_rdata[27]}]\
           [get_ports {o_s_axil_rdata[28]}]\
           [get_ports {o_s_axil_rdata[29]}]\
           [get_ports {o_s_axil_rdata[2]}]\
           [get_ports {o_s_axil_rdata[30]}]\
           [get_ports {o_s_axil_rdata[31]}]\
           [get_ports {o_s_axil_rdata[3]}]\
           [get_ports {o_s_axil_rdata[4]}]\
           [get_ports {o_s_axil_rdata[5]}]\
           [get_ports {o_s_axil_rdata[6]}]\
           [get_ports {o_s_axil_rdata[7]}]\
           [get_ports {o_s_axil_rdata[8]}]\
           [get_ports {o_s_axil_rdata[9]}]\
           [get_ports {o_s_axil_rresp[0]}]\
           [get_ports {o_s_axil_rresp[1]}]\
           [get_ports {o_s_axil_rvalid}]\
           [get_ports {o_s_axil_wready}]]
set_false_path\
    -from [get_ports {rstn}]
set_false_path\
    -to [list [get_pins {u_sram.u_m0/rstb}]\
           [get_pins {u_sram.u_m1/rstb}]]
###############################################################################
# Environment
###############################################################################
set_load -pin_load 0.0300 [get_ports {o_m_axi_arvalid}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awvalid}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_bready}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_rready}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wlast}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wvalid}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_arready}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_awready}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_bvalid}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rvalid}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_wready}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[31]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[30]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[29]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[28]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[27]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[26]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[25]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[24]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[23]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[22]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[21]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[20]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[19]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[18]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[17]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[16]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[15]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[14]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[13]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[12]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[11]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[10]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[9]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[8]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[7]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[6]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[5]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[4]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[3]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[2]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[1]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_araddr[0]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[7]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[6]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[5]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[4]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[3]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[2]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[1]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_arlen[0]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[31]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[30]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[29]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[28]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[27]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[26]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[25]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[24]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[23]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[22]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[21]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[20]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[19]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[18]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[17]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[16]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[15]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[14]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[13]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[12]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[11]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[10]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[9]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[8]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[7]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[6]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[5]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[4]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[3]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[2]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[1]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_awaddr[0]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[31]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[30]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[29]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[28]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[27]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[26]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[25]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[24]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[23]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[22]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[21]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[20]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[19]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[18]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[17]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[16]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[15]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[14]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[13]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[12]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[11]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[10]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[9]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[8]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[7]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[6]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[5]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[4]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[3]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[2]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[1]}]
set_load -pin_load 0.0300 [get_ports {o_m_axi_wdata[0]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_bresp[1]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_bresp[0]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[31]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[30]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[29]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[28]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[27]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[26]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[25]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[24]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[23]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[22]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[21]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[20]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[19]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[18]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[17]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[16]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[15]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[14]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[13]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[12]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[11]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[10]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[9]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[8]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[7]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[6]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[5]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[4]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[3]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[2]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[1]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rdata[0]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rresp[1]}]
set_load -pin_load 0.0300 [get_ports {o_s_axil_rresp[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_arready}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_awready}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_bvalid}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rlast}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rvalid}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_wready}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_arvalid}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awvalid}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_bready}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_rready}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wvalid}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {rstn}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_bresp[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_bresp[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[31]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[30]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[29]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[28]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[27]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[26]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[25]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[24]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[23]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[22]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[21]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[20]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[19]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[18]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[17]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[16]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[15]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[14]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[13]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[12]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[11]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[10]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[9]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[8]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[7]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[6]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[5]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[4]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[3]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[2]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rdata[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rresp[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_m_axi_rresp[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[7]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[6]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[5]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[4]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[3]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[2]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_araddr[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[7]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[6]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[5]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[4]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[3]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[2]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_awaddr[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[31]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[30]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[29]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[28]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[27]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[26]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[25]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[24]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[23]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[22]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[21]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[20]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[19]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[18]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[17]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[16]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[15]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[14]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[13]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[12]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[11]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[10]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[9]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[8]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[7]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[6]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[5]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[4]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[3]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[2]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wdata[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wstrb[3]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wstrb[2]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wstrb[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin {X} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {i_s_axil_wstrb[0]}]
set_timing_derate -early 0.9800
set_timing_derate -late 1.0200
###############################################################################
# Design Rules
###############################################################################
set_max_transition 0.8500 [current_design]
set_max_fanout 21.0000 [current_design]
