`include "config.h"

module system (
	// Clock and reset
	input logic clk, n_reset,
	// GPIO
	inout wire [`DATA_N - 1 : 0] io[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck
);

// Interconnections and buses
logic bus_we, bus_oe;
wire [`ADDR_N : 0] bus_addr;
wire [`DATA_N - 1 : 0] bus_data;

cpu cpu0 (.*);

peripherals periph0 (
	.periphs_sel((bus_addr & ~PERIPH_MASK) == `PERIPH_BASE),
	.periphs_addr(bus_addr[`PERIPHS_N : 0]),
	.*);

endmodule
