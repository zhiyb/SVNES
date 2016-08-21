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
	rom[0:69] = '{
		'ha9, 'h55,			// LDA #$55
		'ha2, 'h5a,			// LDX #$5a
		'ha0, 'ha5,			// LDY #$a5
		'h8d, 'h00, 'h30, // STA $3000
		'h8e, 'h00, 'h30, // STX $3000
		'h8c, 'h00, 'h30, // STY $3000
		'ha9, 'h00,			// LDA #$00
		'h6d, 'h00, 'h30,	// ADC $3000
		'hed, 'h00, 'h30,	// SBC $3000
		'h0d, 'h00, 'h30,	// ORA $3000
		'ha9, 'hff,			// LDA #$ff
		'h2d, 'h00, 'h30,	// AND $3000
		'h4d, 'h00, 'h30,	// EOR $3000
		'had, 'h00, 'h30,	// LDA $3000
		'hae, 'h00, 'h30,	// LDX $3000
		'hac, 'h00, 'h30,	// LDY $3000
		'he8,					// INX
		'hc8,					// INY
		'hca,					// DEX
		'h88,					// DEY
		'ha9, 'h55,			// LDA #$55
		'h69, 'h55,			// ADC #$55
		'he9, 'h22,			// SBC #$22
		'h29, 'haa,			// AND #$55
		'h09, 'h55,			// ORA #$aa
		'h49, 'h33,			// EOR #$5a
		'h0a,					// ASL
		'h4a,					// LSR
		'ha9, 'h55,			// LDA #$81
		'h2a,					// ROL
		'ha9, 'h55,			// LDA #$81
		'h6a,					// ROR
		'h4c, 'h00, 'hff	// JMP #$ff00
	};
	rom['hfc:'hfd] = '{'h00, 'hff};	// Reset vector
end

assign oe = sysbus.addr >= `BOOTROM_BASE;
assign sysbus.data = oe ? rom[sysbus.addr[`BOOTROM_N - 1:0]] : 'bz;

endmodule
