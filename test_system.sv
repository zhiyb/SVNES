`timescale 1 ps / 1 ps
`include "config.h"
import typepkg::*;

module test_system;

logic clk, n_reset_in, n_reset, dbg;

logic irq, nmi;

// GPIO
wire [`DATA_N - 1:0] io[2];
dataLogic iodir[2];
// SPI
logic cs, miso;
logic mosi, sck;

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
	clk = 1'b0;
	forever #500ns clk = ~clk;
end

endmodule
