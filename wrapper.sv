`include "config.h"
import typepkg::*;

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

logic n_reset_in, n_reset, clk1, clk1M, clk1k25, clk50M, dbg;

assign n_reset_in = KEY[1];
assign clk50M = CLOCK_50;

pll pll0 (.areset(~n_reset_in), .inclk0(clk50M), .c0(clk1M), .c4(clk1k25));

counter #(.n($clog2(1250 - 1))) p1 (.top(1250 - 1), .clk(clk1k25), .n_reset(n_reset_in), .out(clk1));

// GPIO
wire [`DATA_N - 1 : 0] io[2];
dataLogic iodir[2];

dataLogic ioin;
assign ioin = {GPIO_1_IN, GPIO_0_IN, SW};

genvar i;
generate
	for (i = 0; i != `DATA_N; i++) begin: gen_io0
		assign io[0][i] = iodir[0][i] ? 1'bz : ioin[i];
	end
endgenerate

//assign LED[6:0] = io[1][6:0];
assign LED[0] = clk50M;
assign LED[1] = clk1M;
assign LED[2] = clk1;
assign LED[3] = io[1][0];
assign LED[4] = io[1][1];
assign LED[5] = dbg;
assign LED[6] = n_reset;
assign LED[7] = n_reset_in;

// SPI
logic cs, miso;
logic mosi, sck;

logic irq, nmi;
assign irq = 1'b1, nmi = 1'b1;

// Audio
logic audio;
assign GPIO_0[25] = audio;

system sys0 (.clk(clk1M), .*);

endmodule
