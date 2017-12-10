module debug (
	input logic clkDebug, n_reset,
	// Processor requests
	output logic [19:0] addr,
	output logic [15:0] data,
	output logic req
);

// Clock generation
logic clk, dclk;
always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset) begin
		clk <= 1'b1;
		dclk <= 1'b1;
	end else begin
		clk <= ~clk;
		dclk <= clk;
	end

logic clkRAM;
always_ff @(negedge clkDebug, negedge n_reset)
	if (~n_reset)
		clkRAM <= 1'b1;
	else
		clkRAM <= clk;

// Processor
logic reset;
logic nmi, irq;
logic sys_rdy;
logic [15:0] sys_addr;
wire [7:0] sys_data;
logic sys_rw;
cpu cpu0 (clk, dclk, n_reset, reset, nmi, irq,
	sys_rdy, sys_addr, sys_data, sys_rw);

assign sys_reset = 1'b0;
assign nmi = 1'b1;
assign irq = 1'b1;
assign sys_rdy = 1'b1;

// RAM at $0000 to $2000 of size $0800 (2kB)
logic ram0sel;
assign ram0sel = (sys_addr & ~16'h1fff) == 16'h0000;
logic [7:0] ram0q;
ram2k ram0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[10:0]), .data(sys_data),
	.wren(ram0sel & ~sys_rw), .q(ram0q));
assign sys_data = (ram0sel & sys_rw) ? ram0q : 8'bz;

// ROM at $8000 to $10000 of size $1000 (4kB)
logic rom0sel;
assign rom0sel = (sys_addr & ~16'h7fff) == 16'h8000;
logic [7:0] rom0q;
debug_rom rom0 (.clock(clkRAM), .address(sys_addr[11:0]), .q(rom0q));
assign sys_data = (rom0sel & sys_rw) ? rom0q : 8'bz;

// Frame buffer access at $6000 to $7000
logic fb_sel;
assign fb_sel = (sys_addr & ~16'h0fff) == 16'h6000;
logic [19:0] fb_addr, fb_addrn, fb_addrp;
logic [15:0] fb_data;
always_ff @(posedge clkRAM)
	fb_addrn <= fb_addr + 1;
// Registers: addr[3], RESERVED, data[2], RESERVED[2]
logic [7:0] regs[8];
assign fb_addr = {regs[2][3:0], regs[1], regs[0]};
assign fb_data = {regs[5], regs[4]};
assign sys_data = (fb_sel & sys_rw) ? regs[sys_addr[2:0]] : 8'bz;
always_ff @(posedge clkRAM)
	if (fb_sel & ~sys_rw) begin
		regs[sys_addr[2:0]] <= sys_data;
		if (sys_addr[2:0] == 3'h4)
			{regs[2][3:0], regs[1], regs[0]} <= fb_addrn;
	end
// clkDebug synchronisation
logic fb_req;
assign fb_req = fb_sel & ~sys_rw && sys_addr[2:0] == 3'h4;
always_ff @(posedge clkRAM)
	fb_addrp <= fb_addr;
always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset) begin
		addr <= 0;
		data <= 0;
		req <= 1'b0;
	end else begin
		addr <= fb_addrp;
		data <= fb_data;
		if (req)
			req <= 1'b0;
		else if (fb_req)
			req <= 1'b1;
	end

endmodule
