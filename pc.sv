`include "config.h"

module pc (
	// Clock, reset and buses
	input logic clk, n_reset,
	input wire [`DATA_N - 1 : 0] bus_data,
	output logic [`ADDR_N : 0] pc
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		pc <= 'b0;
	else
		pc <= pc + 2;

endmodule
