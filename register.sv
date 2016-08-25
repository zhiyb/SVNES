`include "config.h"
import typepkg::*;

module register (
	sys_if sys,
	input logic we, oe,
	output dataLogic data,
	input dataLogic in,
	output wire [`DATA_N - 1:0] out
);

assign out = oe ? data : {`DATA_N{1'bz}};

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		data <= 'h0;
	else if (we)
		data <= in;

endmodule
