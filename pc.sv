`include "config.h"

module pc (
	// Clock, reset and buses
	input logic clk, n_reset,
	input logic pc_addr_oe,
	input logic [1:0] pc_bytes,
	input wire [`DATA_N - 1:0] bus_data,
	output wire [`ADDR_N - 1:0] bus_addr
);

logic [`ADDR_N - 1:0] pc;

assign bus_addr = pc_addr_oe ? pc : 'bz;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		pc <= 'b0;
	else
		pc <= pc + pc_bytes;

endmodule
