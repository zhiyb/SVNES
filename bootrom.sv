`include "config.h"
import typepkg::*;

module bootrom (
	sys_if sys,
	sysbus_if sysbus
);

logic [7:0] rom[`BOOTROM_SIZE];

always_comb
begin
	rom = '{`BOOTROM_SIZE{'h00}};
	rom[0:6] = '{
		'ha9, 'h55,			// LDA $55
		'he9, 'h22,			// SBC $22
		'h4c, 'h04, 'h00	// JMP $0004
	};
end

assign oe = sysbus.addr < `BOOTROM_SIZE;
assign sysbus.data = oe ? rom[sysbus.addr] : 'bz;

endmodule
