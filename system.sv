module system (
	// Clock and reset
	input logic clkCPU, clkPPU, n_reset_in,
	output logic fetch,
	// GPIO
	inout wire [7:0] io[2],
	output logic [7:0] iodir[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck,
	// Audio
	output logic [7:0] audio,
	// Graphics
	output logic [8:0] ppu_x, ppu_y,
	output logic [23:0] ppu_rgb,
	output logic ppu_we
);

sys_if sys (.clk(clkCPU), .nclk(~clkCPU), .*);

// Reset signal reformation
logic n_reset;
always_ff @(posedge sys.clk)
	n_reset <= n_reset_in;

// Interconnections and buses
parameter ARBN = 2;
wire rdy, we;
logic req[ARBN], sel[ARBN], rdy_sel[ARBN], we_sel[ARBN];
wire [15:0] addr, addr_sel[ARBN];
wire [7:0] data;
sysbus_if sysbus (.*);

// PPU bus
logic [13:0] ppu_addr;
wire [7:0] ppu_data;
logic ppu_bus_we;

// PPU
logic ppu_nmi;
ppu ppu0 (.nmi(ppu_nmi), .ppu_we(ppu_bus_we),
	.out_x(ppu_x), .out_y(ppu_y), .out_rgb(ppu_rgb), .out_we(ppu_we), .*);

// PPU pattern table RAM
logic [7:0] ppu_ram0q;
assign ppu_data = ~ppu_bus_we && ppu_addr[13] == 1'b0 ? ppu_ram0q : 8'bz;
ram8k ppu_ram0 (
	.aclr(~sys.n_reset), .clock(clkPPU),
	.address(ppu_addr[12:0]), .data(ppu_data),
	.wren(ppu_bus_we && ppu_addr[13] == 1'b0), .q(ppu_ram0q));

// PPU nametable RAM
logic [7:0] ppu_ram1q;
assign ppu_data = ~ppu_bus_we && ppu_addr[13] == 1'b1 ? ppu_ram1q : 8'bz;
ram8k ppu_ram1 (
	.aclr(~sys.n_reset), .clock(clkPPU),
	.address(ppu_addr[12:0]), .data(ppu_data),
	.wren(ppu_bus_we && ppu_addr[13] == 1'b1), .q(ppu_ram1q));

// CPU bus arbiter
genvar i;
generate
for (i = 0; i != ARBN; i++) begin: gensel
	assign addr = sel[i] ? addr_sel[i] : 16'bz;
	assign we = sel[i] ? we_sel[i] : 1'bz;
end
endgenerate

arbiter #(.N(ARBN)) arb0 (.n_reset(sys.n_reset), .clk(sys.clk),
	.ifrdy(rdy), .ifreq(), .ifswap(1'b0), .req(req), .sel(sel), .rdy(rdy_sel));

// CPU and peripherals attached to CPU bus
logic apu_irq;
assign we_sel[1] = 1'b0;
apu apu0 (
	.bus_req(req[1]), .bus_rdy(rdy_sel[1]), .bus_addr(addr_sel[1]),
	.irq(apu_irq), .out(audio), .*);

assign req[0] = 1'b1;
cpu cpu0 (.irq(apu_irq), .nmi(ppu_nmi),
	.addr(addr_sel[0]), .we(we_sel[0]), .rdy(rdy_sel[0]), .*);

peripherals periph0 (.*);

// RAM at $0000 to $2000 of size $0800 (2kB)
logic ram0sel;
assign ram0sel = (sysbus.addr & ~16'h1fff) == 16'h0000;
assign rdy = ram0sel ? 1'b1 : 1'bz;
logic [7:0] ram0q;
ram2k ram0 (
	.clock(sys.nclk), .aclr(~sys.n_reset),
	.address(sysbus.addr[10:0]), .data(sysbus.data),
	.wren(ram0sel & sysbus.we), .q(ram0q));
assign sysbus.data = (ram0sel & ~sysbus.we) ? ram0q : 8'bz;

// SRAM at $6000 to $8000 of size $2000 (8kB)
logic ram1sel;
assign ram1sel = (sysbus.addr & ~16'h1fff) == 16'h6000;
assign rdy = ram1sel ? 1'b1 : 1'bz;
logic [7:0] ram1q;
ram8k ram1 (
	.clock(sys.nclk), .aclr(~sys.n_reset),
	.address(sysbus.addr[12:0]), .data(sysbus.data),
	.wren(ram1sel & sysbus.we), .q(ram1q));
assign sysbus.data = (ram1sel & ~sysbus.we) ? ram1q : 8'bz;

// Startup ROM at $8000 to $10000 of size $8000 (32kB)
logic rom0sel;
assign rom0sel = (sysbus.addr & ~16'h7fff) == 16'h8000;
assign rdy = rom0sel ? 1'b1 : 1'bz;
logic [7:0] rom0q;
rom32k rom0 (
	.clock(sys.nclk), .aclr(~sys.n_reset),
	.address(sysbus.addr[14:0]), .q(rom0q));
assign sysbus.data = (rom0sel & ~sysbus.we) ? rom0q : 8'bz;

endmodule
