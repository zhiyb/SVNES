`include "config.h"

module pc (
	sys_if sys,
	sysbus_if sysbus,
	// Read & write control
	input logic pc_addr_oe, pc_oe,
	input logic pc_inc, pc_next,
	input logic [1:0] pc_bytes
);

logic [`ADDR_N - 1:0] pc;

assign sysbus.addr = pc_addr_oe ? pc : 'bz;
assign sysbus.data = pc_oe ? pc : 'bz;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		pc <= 'b0;
	else if (pc_inc)
		pc <= pc + 1;
	else if (pc_next)
		pc <= pc + pc_bytes;

endmodule
