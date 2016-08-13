`include "config.h"

module system (
	// Clock and reset
	input logic clk, n_reset
	// IO ports
);

// Interconnections and buses
logic bus_we, bus_oe;
addrLogic bus_addr;
dataLogic bus_data;

cpu cpu0 (.*);

endmodule
