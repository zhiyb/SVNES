module apu_dmc (
	sys_if sys,
	sysbus_if sysbus,
	input logic bus_rdy,
	output logic bus_req, bus_we,
	output wire [15:0] bus_addr,
	
	input logic apuclk, qframe, hframe,
	input logic sel, en,
	output logic act, irq,
	output logic [6:0] out
);

assign bus_req = 1'b0, bus_we = 1'b0, bus_addr = 16'bz;

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

logic [7:0] timer_load;
apu_rom_dmc_ntsc rom0 (.aclr(~sys.n_reset), .clock(sys.nclk), .address(rate_load_reg), .q(timer_load));

logic timer_clk;
logic [7:0] timer_cnt;

apu_timer #(.N(8)) t0 (
	.clk(apuclk), .n_reset(sys.n_reset), .clkout(timer_clk),
	.reload(1'b0), .load(timer_load), .cnt(timer_cnt));

// Shift register

// Output level

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		out <= 7'b0;
	else if (we && sysbus.addr[1:0] == 2'd1)
		out <= load_reg;

endmodule
