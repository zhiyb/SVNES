`include "config.h"

module wrapper (
	input logic CLOCK_50,
	input logic [1:0] KEY,
	input logic [3:0] SW,
	output logic [7:0] LED,
	
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_CAS_N, DRAM_RAS_N, DRAM_WE_N,
	inout logic [15:0] DRAM_DQ,
	
	inout logic I2C_SCLK, I2C_SDAT,
	
	output logic G_SENSOR_CS_N,
	input logic G_SENSOR_INT,
	
	output logic ADC_CS_N, ADC_SADDR, ADC_SCLK,
	input logic ADC_SDAT,
	
	inout logic [33:0] GPIO_0,
	input logic [1:0] GPIO_0_IN,
	inout logic [33:0] GPIO_1,
	input logic [1:0] GPIO_1_IN,
	inout logic [12:0] GPIO_2,
	input logic [2:0] GPIO_2_IN
);

logic n_reset_in, n_reset, fetch, dbg;
assign n_reset_in = KEY[1];

logic clk1M, clk10M, clk20M, clk50M;
assign clk50M = CLOCK_50;
logic pll0_locked;
pll pll0 (
	.areset(~n_reset_in), .inclk0(clk50M),
	.c0(clk20M), .c1(clk10M), .c2(clk1M),
	.locked(pll0_locked));

`define NTSC	0
`define PAL		1
`define DENDY	2

logic clkMaster[3], clkPPU[3], clkCPU[3];
//assign clkMaster[`DENDY] = clkMaster[`PAL];
//assign clkPPU[`DENDY] = clkPPU[`PAL];
logic pll1_locked;
pll_ntsc pll1 (
	.areset(~n_reset_in), .inclk0(clk50M),
	.c0(clkMaster[`NTSC]), .c1(clkPPU[`NTSC]), .c2(clkCPU[`NTSC]),
	.locked(pll1_locked));
//pll_pal pll2 (.areset(~n_reset_in), .inclk0(clk50M), .c0(clkPPU[`PAL]), .c1(clkCPU[`DENDY]));

parameter clksel = `NTSC;

logic clk_Master, clk_PPU, clk_CPU;
assign clk_Master = clkMaster[clksel];
assign clk_PPU = clkPPU[clksel];
assign clk_CPU = clkCPU[clksel];

// GPIO
wire [`DATA_N - 1 : 0] io[2];
logic [`DATA_N - 1 : 0] iodir[2];

logic [`DATA_N - 1 : 0] ioin;
assign ioin = {GPIO_1_IN, GPIO_0_IN, SW};

genvar i;
generate
	for (i = 0; i != `DATA_N; i++) begin: gen_io0
		assign io[0][i] = iodir[0][i] ? 1'bz : ioin[i];
	end
endgenerate

// SPI
logic cs, miso;
logic mosi, sck;
assign cs = 1'b1, miso = 1'b1;

logic irq, nmi;
assign irq = 1'b1, nmi = 1'b1;

// Audio
logic [7:0] audio;
logic aout;
assign GPIO_0[25] = aout;
apu_pwm #(.N(8)) pwm0 (.clk(clk20M), .cmp(audio), .q(aout), .en(1'b1), .*);

system sys0 (.*);

assign LED[6:0] = audio;
/*assign LED[0] = io[1][0];
assign LED[1] = io[1][1];
assign LED[2] = io[1][2];
assign LED[3] = io[1][3];
assign LED[4] = ~irq;
assign LED[5] = ~nmi;
assign LED[6] = dbg;
assign LED[7] = n_reset;*/

endmodule
