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

set clkSDRAM {clk|pll0|altpll_component|auto_generated|pll1|clk[1]}
set clkOutSDRAM [get_ports {DRAM_CLK}]
set portsInSDRAM [get_ports { \
	DRAM_DQ[0] DRAM_DQ[1] DRAM_DQ[2] DRAM_DQ[3] DRAM_DQ[4] DRAM_DQ[5] DRAM_DQ[6] DRAM_DQ[7] DRAM_DQ[8] \
	DRAM_DQ[9] DRAM_DQ[10] DRAM_DQ[11] DRAM_DQ[12] DRAM_DQ[13] DRAM_DQ[14] DRAM_DQ[15]}]
set_input_delay -max -clock $clkSDRAM 5.400 -reference_pin $clkOutSDRAM $portsInSDRAM
set_input_delay -min -clock $clkSDRAM 2.700 -reference_pin $clkOutSDRAM $portsInSDRAM
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
set clkOutTFT [get_ports {GPIO_0[29]}]
#create_generated_clock -name {clkTFTIO} -invert -source $clkTFT [get_nets {pll_main|ClkTFTInv}]
#set clkTFT {clkTFTIO}
set portsTFT [get_ports { \
	GPIO_0[0] GPIO_0[1] GPIO_0[2] GPIO_0[3] GPIO_0[4] GPIO_0[5] GPIO_0[6] GPIO_0[7] GPIO_0[8] \
	GPIO_0[10] GPIO_0[11] GPIO_0[13] GPIO_0[14] GPIO_0[16] GPIO_0[17] GPIO_0[18] GPIO_0[19] \
	GPIO_0[21] GPIO_0[22] GPIO_0[23] GPIO_0[24] GPIO_0[25] GPIO_0[26] GPIO_0[28] \
	GPIO_0[30] GPIO_0[31] GPIO_0[33]}]
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

