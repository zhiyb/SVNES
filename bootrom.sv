`include "config.h"

module bootrom (
	// Clock, reset and buses
	input logic bus_oe,
	input bootromLogic bootrom_addr,
	output idataLogic bus_idata
);

idataLogic rom[`BOOTROM_SIZE / 2] = '{
	0:		'h0000,
	1:		'h55aa,
	2:		'haa55,
	3:		'hffff,
	default: 'h0
};

idataLogic data;

assign bus_idata = bus_oe ? data : 'bz;
assign data = rom[bootrom_addr];

endmodule
