module apu_dmc (
	sys_if sys,
	sysbus_if sysbus,
	input logic apuclk, qframe, hframe,
	input logic sel, en,
	output logic act, irq,
	output logic [6:0] out
);

// Registers

logic we;
logic [7:0] regs[4];
apu_registers r0 (.*);

// Separation of register fields

logic irq_en;
assign irq_en = regs[0][7];

logic loop;
assign loop = regs[0][6];

logic [3:0] rate_load_reg;
assign rate_load_reg = regs[0][3:0];

logic [6:0] load_reg;
assign load_reg = regs[1][6:0];

logic [15:0] addr_load_reg;
assign addr_load_reg = {2'b11, regs[2], 6'h0};

logic [11:0] len_load_reg;
assign len_load_reg = {regs[3], 4'h1};

// Sample buffer

// Memory reader

// Timer

logic [8:0] timer_load;
apu_rom_dmc_ntsc rom0 (.aclr(~sys.n_reset), .clock(sys.nclk), .address(rate_load_reg), .q(timer_load[8:1]));
assign timer_load[0] = 1'b1;

// Shift register

// Output level

assign out = 7'b0;

endmodule
