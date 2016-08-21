`include "config.h"

module test_system;

logic clk, n_reset, n_reset_in;

// GPIO
wire [`DATA_N - 1:0] io[2];
// SPI
logic cs, miso;
logic mosi, sck;

system sys0 (.*);

assign io[1] = ~io[0];

initial
begin
	n_reset_in = 1'b1;
	#1us n_reset_in = 1'b1;
end

initial
begin
	clk = 1'b0;
	forever #500ns clk = ~clk;
end

endmodule
