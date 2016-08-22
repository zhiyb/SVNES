`include "config.h"

module pc (
	sys_if sys,
	sysbus_if sysbus,
	// Read & write control
	input logic pc_addr_oe,
	input logic pc_inc, pc_load,
	input logic oeh, oel,
	input logic weh, wel,
	input logic [`DATA_N - 1:0] in,
	output wire [`DATA_N - 1:0] out,
	input logic [`ADDR_N - 1:0] load
);

logic [`ADDR_N - 1:0] pc;

assign sysbus.addr = pc_addr_oe ? pc : {`ADDR_N{1'bz}};

assign out = oeh ? pc[`ADDR_N - 1:`ADDR_N - `DATA_N] : {`DATA_N{1'bz}};
assign out = oel ? pc[`DATA_N - 1:0] : {`DATA_N{1'bz}};

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		pc <= 16'hfffc;
	else if (pc_inc)
		pc <= pc + 16'h1;
	else if (pc_load)
		pc <= load;
	else if (weh)
		pc[`ADDR_N - 1:`ADDR_N - `DATA_N] <= in;
	else if (wel)
		pc[`DATA_N - 1:0] <= in;

endmodule
