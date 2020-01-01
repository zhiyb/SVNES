## Generated SDC file "C:/Design/SVNES/platform/DE0_Nano.sdc"

## Copyright (C) 2018  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 18.1.0 Build 625 09/12/2018 SJ Lite Edition"

## DATE    "Wed Jan 01 05:38:49 2020"

##
## DEVICE  "EP4CE22F17C6"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLOCK_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {CLOCK_50}]


#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks -create_base_clocks
create_generated_clock -name {ClkTFT} -source [get_pins {pll_main|pll|cyclone_iv.pll|auto_generated|pll1|clk[3]}] -master_clock {pll_main|pll|cyclone_iv.pll|auto_generated|pll1|clk[3]} [get_ports {GPIO_0[29]}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************



#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[0]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[1]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[2]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[3]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[4]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[5]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[6]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[7]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[8]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[10]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[11]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[13]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[14]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[16]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[17]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[18]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[19]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[21]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[22]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[23]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[24]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[25]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[26]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[28]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[30]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[31]}]
set_output_delay -add_delay  -clock [get_clocks {ClkTFT}]  8.000 [get_ports {GPIO_0[33]}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports {LED*}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

