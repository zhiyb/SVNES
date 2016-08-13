`include "config.h"

module bootrom (
	// Clock, reset and buses
	input logic bus_oe,
	input logic [`BOOTROM_N : 0] bootrom_addr,
	output wire [`IDATA_N - 1 : 0] bus_idata
);

logic [`IDATA_N - 1 : 0] rom[`BOOTROM_SIZE / (`IDATA_N / 8)] = '{
	0:		'h0000,
	1:		'h55aa,
	2:		'haa55,
	3:		'hffff,
	default: 'h0
};

logic [`IDATA_N - 1 : 0] data;

assign bus_idata = bus_oe ? data : 'bz;
assign data = rom[bootrom_addr];

endmodule
