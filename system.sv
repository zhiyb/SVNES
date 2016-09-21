module system (
	// Clock and reset
	input logic clk_CPU, clk_PPU, n_reset_in,
	output logic n_reset, fetch, dbg,
	// GPIO
	inout wire [7:0] io[2],
	output logic [7:0] iodir[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck,
	// Audio
	output logic [7:0] audio,
	// Graphics
	output logic [23:0] ppu_addr,
	output logic [23:0] ppu_rgb
);

// Graphic output test
logic [1:0] cnt;
always_ff @(posedge clk_PPU, negedge n_reset_in)
	if (~n_reset_in) begin
		ppu_addr <= 24'hf00000;
		ppu_rgb <= 24'h0000ff;
		cnt <= 2'h0;
	end else if (ppu_addr == 24'hf1fdff) begin
		ppu_addr <= 24'hf00000;
		if (cnt == 2'h0)
			ppu_rgb <= {ppu_rgb[22:0], ppu_rgb[23]};
		cnt <= cnt + 2'h1;
	end else begin
		ppu_addr <= ppu_addr + 24'h1;
	end

assign dbg = 1'b0;

sys_if sys (.clk(clk_CPU), .nclk(~clk_CPU), .*);

// Reset signal reformation
always_ff @(posedge sys.clk, negedge n_reset_in)
	if (~n_reset_in)
		n_reset <= 1'b0;
	else
		n_reset <= 1'b1;

// Interconnections and buses
parameter ARBN = 2;
wire rdy, we;
logic req[ARBN], sel[ARBN], rdy_sel[ARBN], we_sel[ARBN];
wire [15:0] addr, addr_sel[ARBN];
wire [7:0] data;
sysbus_if sysbus (.*);

genvar i;
generate
for (i = 0; i != ARBN; i++) begin: gensel
	assign addr = sel[i] ? addr_sel[i] : 16'bz;
	assign we = sel[i] ? we_sel[i] : 1'bz;
end
endgenerate

arbiter #(.N(ARBN)) arb0 (.n_reset(sys.n_reset), .clk(sys.clk),
	.ifrdy(rdy), .ifreq(), .ifswap(1'b0), .req(req), .sel(sel), .rdy(rdy_sel));

logic ppu_nmi;
logic ppu_req;
assign ppu_req = 1'b0;
ppu ppu0 (.nmi(ppu_nmi), .*);

logic apu_irq;
assign we_sel[1] = 1'b0;
apu apu0 (
	.bus_req(req[1]), .bus_rdy(rdy_sel[1]), .bus_addr(addr_sel[1]),
	.irq(apu_irq), .out(audio), .*);

assign req[0] = ~ppu_req;
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
