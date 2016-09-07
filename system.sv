`include "config.h"

module system (
	// Clock and reset
	input logic clk_CPU, clk_PPU, n_reset_in,
	output logic n_reset, fetch, dbg,
	// Interrupt lines
	input logic irq, nmi,
	// GPIO
	inout wire [7:0] io[2],
	output logic [7:0] iodir[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck,
	// Audio
	output logic [7:0] audio
);

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

arbiter #(.N(ARBN)) arb0 (.ifrdy(rdy), .req(req), .sel(sel), .rdy(rdy_sel), .*);

logic apu_irq;
apu apu0 (
	.bus_req(req[1]), .bus_rdy(rdy_sel[1]),
	.bus_we(we_sel[1]), .bus_addr(addr_sel[1]),
	.irq(apu_irq), .out(audio), .*);

logic cpu_irq;
assign cpu_irq = irq & apu_irq;
assign req[0] = 1'b1;
cpu cpu0 (.irq(cpu_irq), .addr(addr_sel[0]), .we(we_sel[0]), .rdy(rdy_sel[0]), .*);

peripherals periph0 (.*);

logic rom0sel;
assign rom0sel = sysbus.addr >= `BOOTROM_BASE;
logic [7:0] rom0q;
assign rdy = rom0sel ? 1'b1 : 1'bz;
assign sysbus.data = (~sysbus.we & rom0sel) ? rom0q : 8'bz;
rom rom0 (
	.clock(sys.nclk), .aclr(~sys.n_reset),
	.address(sysbus.addr[7:0]), .q(rom0q));

logic ram0sel;
assign ram0sel = sysbus.addr < `RAM0_SIZE;
logic [7:0] ram0q;
assign rdy = ram0sel ? 1'b1 : 1'bz;
assign sysbus.data = (~sysbus.we & ram0sel) ? ram0q : 8'bz;
ram2k ram0 (
	.clock(sys.nclk), .aclr(~sys.n_reset),
	.address(sysbus.addr[10:0]), .data(sysbus.data),
	.wren(sysbus.we & ram0sel), .q(ram0q));

endmodule
