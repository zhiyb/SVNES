module apu_registers (
	input logic clk, dclk, n_reset,

	input logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	input logic sys_rw,

	input logic sel,
	output logic we,
	output logic [7:0] regs[4]
);

assign we = sel & sys_rw;

always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		for (int i = 0; i != 4; i++)
			regs[i] <= 8'b0;
	else if (we)
		regs[sys_addr[1:0]] <= sys_data;

endmodule
