`include "config.h"
import typepkg::*;

module bootrom (
	// Clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe,
	input wire [ADDR_N - 1:0] bus_addr,
	output wire [DATA_N - 1:0] bus_data
);

logic [7:0] rom[BOOTROM_SIZE] = '{
	0:		'h00,
	1:		'h55,
	2:		'haa,
	3:		'hff,
	default: 'h0
};

logic oe;
assign oe = bus_oe && (bus_addr < BOOTROM_SIZE);
assign bus_data = oe ? rom[bus_addr] : 'bz;

endmodule
