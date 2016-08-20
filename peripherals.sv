`include "config.h"

module peripherals (
	sys_if sys,
	sysbus_if sysbus,
	// GPIO
	inout wire [`DATA_N - 1:0] io[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck
);

logic [2 ** `PERIPH_MAP_N - 1:0] periph_sel;
demux #(.N(`PERIPH_MAP_N)) demux0 (
	.sel(sysbus.addr[`PERIPHS_N - 1:`PERIPH_N]),
	.oe((sysbus.addr & ~`PERIPH_MASK) == `PERIPH_BASE),
	.q(periph_sel)
);

periphbus_if pbus (
	.we(sysbus.we), .oe(sysbus.oe),
	.data(sysbus.data), .addr(sysbus.addr[`PERIPH_N - 1:0])
);

gpio gpio0 (.sel(periph_sel[0]), .io(io[0]), .*);
gpio gpio1 (.sel(periph_sel[1]), .io(io[1]), .*);

logic interrupt;
spi spi0 (.sel(periph_sel[2]), .*);

endmodule
