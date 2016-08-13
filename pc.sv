`include "config.h"

module pc (
	// Clock, reset and buses
	input logic clk, n_reset,
	input dataLogic bus_data,
	output addrLogic pc
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		pc <= 'b0;
	else
		pc <= pc + 2;

endmodule
