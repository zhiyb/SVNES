module apu_registers (
	sys_if sys,
	sysbus_if sysbus,
	input logic sel,
	output logic we,
	output logic [7:0] regs[4]
);

assign we = sel & sysbus.we;

always_ff @(posedge sys.nclk, negedge sys.n_reset)
	if (~sys.n_reset)
		for (int i = 0; i != 4; i++)
			regs[i] <= 8'b0;
	else if (we)
		regs[sysbus.addr[1:0]] <= sysbus.data;

endmodule
