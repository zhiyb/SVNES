`include "config.h"
import typepkg::*;

module register (
	sys_if sys,
	regbus_if regbus
);

dataLogic data;

assign regbus.data = data;
assign regbus.out = regbus.oe ? data : {`DATA_N{1'bz}};

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		data <= 'h0;
	else if (regbus.we)
		data <= regbus.in;

endmodule
