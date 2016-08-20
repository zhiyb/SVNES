`include "config.h"

module system (
	// Clock and reset
	input logic clk, n_reset_in,
	output logic n_reset = 1'b0,
	// GPIO
	inout wire [`DATA_N - 1:0] io[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck
);

// Reset signal reformation
always_ff @(posedge clk)
	n_reset <= n_reset_in;

// Interconnections and buses
logic bus_we, bus_oe;
wire [`ADDR_N - 1 : 0] bus_addr;
wire [`DATA_N - 1 : 0] bus_data;

cpu cpu0 (.*);

bootrom rom0 (.*);

peripherals periph0 (
	.periphs_sel((bus_addr & ~PERIPH_MASK) == `PERIPH_BASE),
	.periphs_addr(bus_addr[`PERIPHS_N : 0]),
	.*);

endmodule
