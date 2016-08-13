`include "config.h"

module test_system;

logic clk, n_reset;

system sys0 (.*);

initial
begin
	n_reset = 1'b1;
	#1us n_reset = 1'b0;
	#1us n_reset = 1'b1;
end

initial
begin
	clk = 1'b0;
	forever #500ns clk = ~clk;
end

endmodule
