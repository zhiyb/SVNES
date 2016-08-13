`include "config.h"

module cpu (
	// Clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe,
	input addrLogic bus_addr,
	input dataLogic bus_data
);

addrLogic pc;
pc pc0 (.*);

endmodule
