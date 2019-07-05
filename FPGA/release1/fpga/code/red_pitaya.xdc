#
# $Id: red_pitaya.xdc 961 2014-01-21 11:40:39Z matej.oblak $
#
# @brief Red Pitaya location constraints.
#
# @Author Matej Oblak
#
# (c) Red Pitaya  http://www.redpitaya.com
#


############################################################################
# IO constraints                                                           #
############################################################################

### ADC

set_property IOSTANDARD LVCMOS18 [get_ports {adc_dat_a_i[*]}]
set_property IOB TRUE [get_ports {adc_dat_a_i[*]}]
#set_property PACKAGE_PIN V17 [get_ports {adc_dat_a_i[0]}]
#set_property PACKAGE_PIN U17 [get_ports {adc_dat_a_i[1]}]
set_property PACKAGE_PIN Y17 [get_ports {adc_dat_a_i[2]}]
set_property PACKAGE_PIN W16 [get_ports {adc_dat_a_i[3]}]
set_property PACKAGE_PIN Y16 [get_ports {adc_dat_a_i[4]}]
set_property PACKAGE_PIN W15 [get_ports {adc_dat_a_i[5]}]
set_property PACKAGE_PIN W14 [get_ports {adc_dat_a_i[6]}]
set_property PACKAGE_PIN Y14 [get_ports {adc_dat_a_i[7]}]
set_property PACKAGE_PIN W13 [get_ports {adc_dat_a_i[8]}]
set_property PACKAGE_PIN V12 [get_ports {adc_dat_a_i[9]}]
set_property PACKAGE_PIN V13 [get_ports {adc_dat_a_i[10]}]
set_property PACKAGE_PIN T14 [get_ports {adc_dat_a_i[11]}]
set_property PACKAGE_PIN T15 [get_ports {adc_dat_a_i[12]}]
set_property PACKAGE_PIN V15 [get_ports {adc_dat_a_i[13]}]
set_property PACKAGE_PIN T16 [get_ports {adc_dat_a_i[14]}]
set_property PACKAGE_PIN V16 [get_ports {adc_dat_a_i[15]}]



set_property IOSTANDARD LVCMOS18 [get_ports {adc_dat_b_i[*]}]
set_property IOB TRUE [get_ports {adc_dat_b_i[*]}]
#set_property PACKAGE_PIN T17 [get_ports {adc_dat_b_i[0]}]
#set_property PACKAGE_PIN R16 [get_ports {adc_dat_b_i[1]}]
set_property PACKAGE_PIN R18 [get_ports {adc_dat_b_i[2]}]
set_property PACKAGE_PIN P16 [get_ports {adc_dat_b_i[3]}]
set_property PACKAGE_PIN P18 [get_ports {adc_dat_b_i[4]}]
set_property PACKAGE_PIN N17 [get_ports {adc_dat_b_i[5]}]
set_property PACKAGE_PIN R19 [get_ports {adc_dat_b_i[6]}]
set_property PACKAGE_PIN T20 [get_ports {adc_dat_b_i[7]}]
set_property PACKAGE_PIN T19 [get_ports {adc_dat_b_i[8]}]
set_property PACKAGE_PIN U20 [get_ports {adc_dat_b_i[9]}]
set_property PACKAGE_PIN V20 [get_ports {adc_dat_b_i[10]}]
set_property PACKAGE_PIN W20 [get_ports {adc_dat_b_i[11]}]
set_property PACKAGE_PIN W19 [get_ports {adc_dat_b_i[12]}]
set_property PACKAGE_PIN Y19 [get_ports {adc_dat_b_i[13]}]
set_property PACKAGE_PIN W18 [get_ports {adc_dat_b_i[14]}]
set_property PACKAGE_PIN Y18 [get_ports {adc_dat_b_i[15]}]


set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_p_i]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_n_i]
set_property PACKAGE_PIN U18 [get_ports adc_clk_p_i]
set_property PACKAGE_PIN U19 [get_ports adc_clk_n_i]


# Output ADC clock
set_property IOSTANDARD LVCMOS18 [get_ports {adc_clk_o[*]}]
set_property SLEW FAST [get_ports {adc_clk_o[*]}]
set_property DRIVE 8 [get_ports {adc_clk_o[*]}]
#set_property IOB TRUE [get_ports {adc_clk_o[*]}]

set_property PACKAGE_PIN N20 [get_ports {adc_clk_o[0]}]
set_property PACKAGE_PIN P20 [get_ports {adc_clk_o[1]}]


# ADC clock stabilizer
set_property IOSTANDARD LVCMOS18 [get_ports adc_cdcs_o]
set_property PACKAGE_PIN V18 [get_ports adc_cdcs_o]
set_property SLEW FAST [get_ports adc_cdcs_o]
set_property DRIVE 8 [get_ports adc_cdcs_o]








### XADC
set_property IOSTANDARD TMDS_33 [get_ports {vinp_i[*]}]
set_property IOSTANDARD TMDS_33 [get_ports {vinn_i[*]}]
set_property LOC XADC_X0Y0 [get_cells i_ams/XADC_inst]
#AD0
set_property PACKAGE_PIN C20 [get_ports {vinp_i[0]}]
set_property PACKAGE_PIN B20 [get_ports {vinn_i[0]}]
#AD1
set_property PACKAGE_PIN E17 [get_ports {vinp_i[1]}]
set_property PACKAGE_PIN D18 [get_ports {vinn_i[1]}]
#AD8
set_property PACKAGE_PIN B19 [get_ports {vinp_i[2]}]
set_property PACKAGE_PIN A20 [get_ports {vinn_i[2]}]
#AD9
set_property PACKAGE_PIN E18 [get_ports {vinp_i[3]}]
set_property PACKAGE_PIN E19 [get_ports {vinn_i[3]}]
#V_0
set_property PACKAGE_PIN K9  [get_ports {vinp_i[4]}]
set_property PACKAGE_PIN L10 [get_ports {vinn_i[4]}]















### Expansion connector
set_property IOSTANDARD LVCMOS33 [get_ports {exp_p_io[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {exp_n_io[*]}]
set_property SLEW FAST [get_ports {exp_p_io[*]}]
set_property SLEW FAST [get_ports {exp_n_io[*]}]
set_property DRIVE 8 [get_ports {exp_p_io[*]}]
set_property DRIVE 8 [get_ports {exp_n_io[*]}]

set_property PACKAGE_PIN G17 [get_ports {exp_p_io[0]}]
set_property PACKAGE_PIN G18 [get_ports {exp_n_io[0]}]
set_property PACKAGE_PIN H16 [get_ports {exp_p_io[1]}]
set_property PACKAGE_PIN H17 [get_ports {exp_n_io[1]}]
set_property PACKAGE_PIN J18 [get_ports {exp_p_io[2]}]
set_property PACKAGE_PIN H18 [get_ports {exp_n_io[2]}]
set_property PACKAGE_PIN K17 [get_ports {exp_p_io[3]}]
set_property PACKAGE_PIN K18 [get_ports {exp_n_io[3]}]
set_property PACKAGE_PIN L14 [get_ports {exp_p_io[4]}]
set_property PACKAGE_PIN L15 [get_ports {exp_n_io[4]}]
set_property PACKAGE_PIN L16 [get_ports {exp_p_io[5]}]
set_property PACKAGE_PIN L17 [get_ports {exp_n_io[5]}]
set_property PACKAGE_PIN K16 [get_ports {exp_p_io[6]}]
set_property PACKAGE_PIN J16 [get_ports {exp_n_io[6]}]
set_property PACKAGE_PIN M14 [get_ports {exp_p_io[7]}]
set_property PACKAGE_PIN M15 [get_ports {exp_n_io[7]}]





#set_property PULLDOWN TRUE [get_ports {exp_p_io[0]}]
#set_property PULLDOWN TRUE [get_ports {exp_n_io[0]}]
#set_property PULLUP   TRUE [get_ports {exp_p_io[7]}]
#set_property PULLUP   TRUE [get_ports {exp_n_io[7]}]


### LED
set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]
set_property SLEW SLOW [get_ports {led_o[*]}]
set_property DRIVE 8 [get_ports {led_o[*]}]

set_property PACKAGE_PIN F16 [get_ports {led_o[0]}]
set_property PACKAGE_PIN F17 [get_ports {led_o[1]}]
set_property PACKAGE_PIN G15 [get_ports {led_o[2]}]
set_property PACKAGE_PIN H15 [get_ports {led_o[3]}]
set_property PACKAGE_PIN K14 [get_ports {led_o[4]}]
set_property PACKAGE_PIN G14 [get_ports {led_o[5]}]
set_property PACKAGE_PIN J15 [get_ports {led_o[6]}]
set_property PACKAGE_PIN J14 [get_ports {led_o[7]}]







############################################################################
# Clock constraints                                                        #
############################################################################
#NET "adc_clk" TNM_NET = "adc_clk";
#TIMESPEC TS_adc_clk = PERIOD "adc_clk" 125 MHz;

create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]

set_input_delay -clock adc_clk 3.400 [get_ports adc_dat_a_i[*]]
set_input_delay -clock adc_clk 3.400 [get_ports adc_dat_b_i[*]]

set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks adc_clk]
