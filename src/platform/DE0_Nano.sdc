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

create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]


#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty


#**************************************************************
# SDRAM constraints
#**************************************************************

set clkSDRAM {clk|pll0|altpll_component|auto_generated|pll1|clk[0]}
set clkOutSDRAM [get_ports {DRAM_CLK}]
set portsInSDRAM [get_ports { \
	DRAM_DQ[0] DRAM_DQ[1] DRAM_DQ[2] DRAM_DQ[3] DRAM_DQ[4] DRAM_DQ[5] DRAM_DQ[6] DRAM_DQ[7] DRAM_DQ[8] \
	DRAM_DQ[9] DRAM_DQ[10] DRAM_DQ[11] DRAM_DQ[12] DRAM_DQ[13] DRAM_DQ[14] DRAM_DQ[15]}]
set_input_delay -max -clock $clkSDRAM 5.4 -reference_pin $clkOutSDRAM $portsInSDRAM
set_input_delay -min -clock $clkSDRAM 2.7 -reference_pin $clkOutSDRAM $portsInSDRAM
# Use the previous cycle for SDC
#set_input_delay -max -clock $clkSDRAM -4.6 -reference_pin $clkOutSDRAM $portsInSDRAM
#set_input_delay -min -clock $clkSDRAM 7.3 -reference_pin $clkOutSDRAM $portsInSDRAM
set portsOutSDRAM [get_ports { \
	DRAM_ADDR[0] DRAM_ADDR[1] DRAM_ADDR[2] DRAM_ADDR[3] DRAM_ADDR[4] DRAM_ADDR[5] DRAM_ADDR[6] DRAM_ADDR[7] \
	DRAM_ADDR[8] DRAM_ADDR[9] DRAM_ADDR[10] DRAM_ADDR[11] DRAM_ADDR[12] DRAM_BA[0] DRAM_BA[1] \
	DRAM_DQ[0] DRAM_DQ[1] DRAM_DQ[2] DRAM_DQ[3] DRAM_DQ[4] DRAM_DQ[5] DRAM_DQ[6] DRAM_DQ[7] DRAM_DQ[8] \
	DRAM_DQ[9] DRAM_DQ[10] DRAM_DQ[11] DRAM_DQ[12] DRAM_DQ[13] DRAM_DQ[14] DRAM_DQ[15] \
	DRAM_DQM[0] DRAM_DQM[1] DRAM_CAS_N DRAM_CKE DRAM_CS_N DRAM_RAS_N DRAM_WE_N}]
set_output_delay -max -clock $clkSDRAM 1.5 -reference_pin $clkOutSDRAM $portsOutSDRAM
set_output_delay -min -clock $clkSDRAM -0.8 -reference_pin $clkOutSDRAM $portsOutSDRAM


#**************************************************************
# TFT constraints
#**************************************************************

set clkTFT {clk|pll0|altpll_component|auto_generated|pll1|clk[2]}
set clkOutTFT [get_ports {GPIO_1[27]}]
#create_generated_clock -name {clkTFTIO} -invert -source $clkTFT [get_nets {pll_main|ClkTFTInv}]
#set clkTFT {clkTFTIO}
set portsTFT [get_ports { \
	GPIO_1[0] GPIO_1[1] GPIO_1[2] GPIO_1[3] GPIO_1[4] GPIO_1[6] GPIO_1[7] GPIO_1[8] \
	GPIO_1[9] GPIO_1[10] GPIO_1[11] GPIO_1[13] GPIO_1[14] GPIO_1[15] GPIO_1[16] GPIO_1[17] \
	GPIO_1[18] GPIO_1[19] GPIO_1[20] GPIO_1[21] GPIO_1[22] GPIO_1[23] GPIO_1[24] GPIO_1[25] \
	GPIO_1[28] GPIO_1[29] GPIO_1[31] GPIO_1[33]}]
set_output_delay -max -clock $clkTFT -clock_fall -reference_pin $clkOutTFT 8.000 $portsTFT
set_output_delay -min -clock $clkTFT -clock_fall -reference_pin $clkOutTFT -8.000 $portsTFT


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports {LED*}]
set_false_path -to [get_ports {GPIO_1*}]
set_false_path -from [get_ports {KEY*}]
set_false_path -from [get_ports {SW*}]

set_false_path -to [get_cells -compatibility_mode *\|cdc_synchron\[*\]\[*\]]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

