## Generated SDC file "C:/Users/zhiyb/Documents/Design/FPGA/SVNES/peripheral/sdram.sdc"

## Copyright (C) 2017  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel MegaCore Function License Agreement, or other 
## applicable license agreement, including, without limitation, 
## that your use is for the sole purpose of programming logic 
## devices manufactured by Intel and sold by Intel or its 
## authorized distributors.  Please refer to the applicable 
## agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 16.1.2 Build 203 01/18/2017 SJ Lite Edition"

## DATE    "Wed Mar 29 20:04:55 2017"

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

create_clock -name {clk50M} -period 20.000 -waveform { 0.000 10.000 } [get_ports {CLOCK_50}]
create_clock -name {clkSDRAM} -period 11.111 -waveform { 0.000 5.556 } 


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************



#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[0]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[0]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[1]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[1]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[2]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[2]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[3]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[3]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[4]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[4]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[5]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[5]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[6]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[6]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[7]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[7]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[8]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[8]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[9]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[9]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[10]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[10]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[11]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[11]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[12]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[12]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[13]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[13]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[14]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[14]}]
set_input_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  5.400 [get_ports {DRAM_DQ[15]}]
set_input_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  2.700 [get_ports {DRAM_DQ[15]}]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[0]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[0]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[1]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[1]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[2]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[2]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[3]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[3]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[4]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[4]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[5]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[5]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[6]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[6]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[7]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[7]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[8]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[8]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[9]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[9]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[10]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[10]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[11]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[11]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_ADDR[12]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_ADDR[12]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_BA[0]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_BA[0]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_BA[1]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_BA[1]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_CAS_N}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_CAS_N}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_CKE}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_CKE}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_CS_N}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_CS_N}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQM[0]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQM[0]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQM[1]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQM[1]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[0]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[0]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[1]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[1]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[2]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[2]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[3]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[3]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[4]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[4]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[5]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[5]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[6]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[6]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[7]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[7]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[8]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[8]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[9]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[9]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[10]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[10]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[11]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[11]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[12]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[12]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[13]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[13]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[14]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[14]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_DQ[15]}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_DQ[15]}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_RAS_N}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_RAS_N}]
set_output_delay -add_delay -max -clock [get_clocks {clkSDRAM}]  1.500 [get_ports {DRAM_WE_N}]
set_output_delay -add_delay -min -clock [get_clocks {clkSDRAM}]  -0.800 [get_ports {DRAM_WE_N}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



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

