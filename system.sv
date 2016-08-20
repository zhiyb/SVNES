`include "config.h"
import typepkg::*;

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
sys_if sys (.*);

// Interconnections and buses
logic we, oe;
wire [`ADDR_N - 1 : 0] addr;
wire [`DATA_N - 1 : 0] data;
sysbus_if sysbus (.*);

cpu cpu0 (.*);

bootrom rom0 (.*);

peripherals periph0 (.*);

endmodule
