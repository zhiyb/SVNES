`include "config.h"

module cpu (
	// Clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe,
	input logic [`ADDR_N : 0] bus_addr,
	inout wire [`DATA_N - 1 : 0] bus_data
);

logic [`ADDR_N : 0] pc;
pc pc0 (.*);

endmodule
