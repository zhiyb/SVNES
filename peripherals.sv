`include "config.h"

module peripherals (
	// Clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe, periphs_sel,
	input periphsLogic periphs_addr,
	inout dataLogic bus_data,
	// GPIO
	inout dataLogic io[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck
);

periphLogic periph_addr;
assign periph_addr = periphs_addr[`PERIPH_N - 1 : 0];

logic [2 ** `PERIPH_MAP_N - 1 : 0] periph_sel;
demux #(.N(`PERIPH_MAP_N)) demux0 (
	.sel(periphs_addr[`PERIPHS_N - 1 : `PERIPH_N]),
	.oe(periphs_sel), .q(periph_sel)
);

gpio gpio0 (.periph_sel(periph_sel[0]), .io(io[0]), .*);
gpio gpio1 (.periph_sel(periph_sel[1]), .io(io[1]), .*);

logic interrupt;
spi spi0 (.periph_sel(periph_sel[2]), .*);

endmodule
