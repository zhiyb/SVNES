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
	rom[0:26] = '{
		'he8,					// INX
		'hc8,					// INY
		'hca,					// DEX
		'h88,					// DEY
		'ha9, 'h55,			// LDA $55
		'h69, 'h55,			// ADC $55
		'he9, 'h22,			// SBC $22
		'h29, 'haa,			// AND $55
		'h09, 'h55,			// ORA $aa
		'h49, 'h33,			// EOR $5a
		'h0a,					// ASL
		'h4a,					// LSR
		'ha9, 'h55,			// LDA $81
		'h2a,					// ROL
		'ha9, 'h55,			// LDA $81
		'h6a,					// ROR
		'h4c, 'h04, 'h00	// JMP $0004
	};
end

assign oe = sysbus.addr < `BOOTROM_SIZE;
assign sysbus.data = oe ? rom[sysbus.addr] : 'bz;

endmodule
