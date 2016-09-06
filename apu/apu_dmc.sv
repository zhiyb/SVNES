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
assign we = sel & sysbus.we;

logic [7:0] regs[4];

always_ff @(negedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		for (int i = 0; i != 4; i++)
			regs[i] <= 8'b0;
	end else if (we) begin
		regs[sysbus.addr[1:0]] <= sysbus.data;
	end

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
