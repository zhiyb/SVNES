`timescale 1 ps / 1 ps
`include "config.h"
import typepkg::*;

module test_system;

logic n_reset_in, n_reset, dbg;
logic clk_CPU, clk_PPU;

logic irq, nmi;

// GPIO
wire [`DATA_N - 1:0] io[2];
dataLogic iodir[2];
// SPI
logic cs, miso;
logic mosi, sck;
// Audio
logic [7:0] audio;

system sys0 (.*);

assign io[0] = io[1];

initial
begin
	nmi = 1'b1;
	#30us nmi = 1'b0;
	#20us nmi = 1'b1;
end

initial
begin
	irq = 1'b1;
end

initial
begin
	n_reset_in = 1'b0;
	#1us n_reset_in = 1'b1;
end

initial
begin
	clk_CPU = 1'b0;
	forever #500ns clk_CPU = ~clk_CPU;
end

initial
begin
	clk_PPU = 1'b0;
	forever #125ns clk_PPU = ~clk_PPU;
end

endmodule
