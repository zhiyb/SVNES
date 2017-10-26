module system (
	input logic clkCPU2, n_reset,
	// Audio
	output logic [7:0] audio
);

// Clock generation
logic clk, dclk;
always_ff @(posedge clkCPU2, negedge n_reset)
	if (~n_reset) begin
		clk <= 1'b1;
		dclk <= 1'b1;
	end else begin
		clk <= ~clk;
		dclk <= clk;
	end

logic clkRAM;
always_ff @(negedge clkCPU2, negedge n_reset)
	if (~n_reset)
		clkRAM <= 1'b1;
	else
		clkRAM <= clk;

// CPU
logic nmi, irq, sys_rw;
wire sys_rdy;
logic [15:0] sys_addr;
wire [7:0] sys_data;
cpu cpu0 (clk, dclk, n_reset, nmi, irq, sys_addr, sys_data, sys_rw);

assign nmi = 1'b1;

// APU
logic [15:0] apu_addr;
logic apu_rdy, apu_req, apu_irq;
logic [7:0] apu_out;
apu apu0 (clk, dclk, n_reset, sys_addr, sys_data, sys_rdy, ~sys_rw,
	apu_addr, apu_rdy, apu_req, apu_irq, apu_out);
assign apu_rdy = 1'b0;
assign irq = apu_irq;
assign audio = apu_out;

// RAM at $0000 to $2000 of size $0800 (2kB)
logic ram0sel;
assign ram0sel = (sys_addr & ~16'h1fff) == 16'h0000;
assign sys_rdy = ram0sel ? 1'b1 : 1'bz;
logic [7:0] ram0q;
ram2k ram0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[10:0]), .data(sys_data),
	.wren(ram0sel & ~sys_rw), .q(ram0q));
assign sys_data = (ram0sel & sys_rw) ? ram0q : 8'bz;

// SRAM at $6000 to $8000 of size $2000 (8kB)
logic ram1sel;
assign ram1sel = (sys_addr & ~16'h1fff) == 16'h6000;
assign sys_rdy = ram1sel ? 1'b1 : 1'bz;
logic [7:0] ram1q;
ram8k ram1 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[12:0]), .data(sys_data),
	.wren(ram1sel & ~sys_rw), .q(ram1q));
assign sys_data = (ram1sel & sys_rw) ? ram1q : 8'bz;

// Startup ROM at $8000 to $10000 of size $8000 (32kB)
logic rom0sel;
assign rom0sel = (sys_addr & ~16'h7fff) == 16'h8000;
assign sys_rdy = rom0sel ? 1'b1 : 1'bz;
logic [7:0] rom0q;
rom4k rom0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[11:0]), .q(rom0q));
assign sys_data = (rom0sel & sys_rw) ? rom0q : 8'bz;

endmodule
