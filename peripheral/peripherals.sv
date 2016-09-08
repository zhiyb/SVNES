module peripherals (
	sys_if sys,
	sysbus_if sysbus,
	// GPIO
	inout wire [7:0] io[2],
	output logic [7:0] iodir[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck
);

logic periphs_sel;
assign periphs_sel = (sysbus.addr & ~16'h00ff) == 16'h3000;
assign sysbus.rdy = periphs_sel ? 1'b1 : 1'bz;

logic [63:0] periph_sel;
demux #(.N(6)) demux0 (
	.sel(sysbus.addr[7:2]),
	.oe(periphs_sel),
	.q(periph_sel)
);

periphbus_if pbus (
	.we(sysbus.we), .data(sysbus.data),
	.addr(sysbus.addr[1:0])
);

gpio gpio0 (.sel(periph_sel[0]), .io(io[0]), .iodir(iodir[0]), .*);
gpio gpio1 (.sel(periph_sel[1]), .io(io[1]), .iodir(iodir[1]), .*);

logic interrupt;
spi spi0 (.sel(periph_sel[2]), .*);

endmodule
