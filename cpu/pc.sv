module pc (
	sys_if sys,
	sysbus_if sysbus,
	// Read & write control
	input logic pc_addr_oe,
	input logic pc_inc, pc_load, pc_int,
	input logic oeh, oel,
	input logic weh, wel,
	input logic [7:0] in,
	output wire [7:0] out,
	input logic [15:0] int_addr, load,
	output logic [15:0] data
);

logic [15:0] pc;
assign data = pc;
assign sysbus.addr = pc_addr_oe ? pc : 16'bz;

assign out = oeh ? pc[15:8] : 8'bz;
assign out = oel ? pc[7:0] : 8'bz;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		pc <= 16'h0;
	else if (pc_inc)
		pc <= pc + 16'h1;
	else if (pc_load)
		pc <= load;
	else if (pc_int)
		pc <= int_addr;
	else if (weh)
		pc[15:8] <= in;
	else if (wel)
		pc[7:0] <= in;

endmodule
