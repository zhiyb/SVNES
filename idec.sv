`include "config.h"
import typepkg::*;

module idec (
	input dataLogic ins,
	output Opcode opcode,
	output Addressing mode,
	output logic [1:0] pc_bytes
);

Opcode LUT_op[256];
assign LUT_op = '{
//	+00	+01	+02	+03	+04	+05	+06	+07	+08	+09	+0a	+0b	+0c	+0d	+0e	+0f
	BRK,	ORA,	KIL,	SLO,	NOP,	ORA,	ASL,	SLO,	PHP,	ORA,	ASL,	ANC,	NOP,	ORA,	ASL,	SLO,	// 00
	BPL,	ORA,	KIL,	SLO,	NOP,	ORA,	ASL,	SLO,	CLC,	ORA,	NOP,	SLO,	NOP,	ORA,	ASL,	SLO,	// 10
	JSR,	AND,	KIL,	RLA,	BIT,	AND,	ROL,	RLA,	PLP,	AND,	ROL,	ANC,	BIT,	AND,	ROL,	RLA,	// 20
	BMI,	AND,	KIL,	RLA,	NOP,	AND,	ROL,	RLA,	SEC,	AND,	NOP,	RLA,	NOP,	AND,	ROL,	RLA,	// 30
	RTI,	EOR,	KIL,	SRE,	NOP,	EOR,	LSR,	SRE,	PHA,	EOR,	LSR,	ALR,	JMP,	EOR,	LSR,	SRE,	// 40
	BVC,	EOR,	KIL,	SRE,	NOP,	EOR,	LSR,	SRE,	CLI,	EOR,	NOP,	SRE,	NOP,	EOR,	LSR,	SRE,	// 50
	RTS,	ADC,	KIL,	RRA,	NOP,	ADC,	ROR,	RRA,	PLA,	ADC,	ROR,	ARR,	JMP,	ADC,	ROR,	RRA,	// 60
	BVS,	ADC,	KIL,	RRA,	NOP,	ADC,	ROR,	RRA,	SEI,	ADC,	NOP,	RRA,	NOP,	ADC,	ROR,	RRA,	// 70
	NOP,	STA,	NOP,	SAX,	STY,	STA,	STX,	SAX,	DEY,	NOP,	TXA,	XAA,	STY,	STA,	STX,	SAX,	// 80
	BCC,	STA,	KIL,	AHX,	STY,	STA,	STX,	SAX,	TYA,	STA,	TXS,	TAS,	SHY,	STA,	SHX,	AHX,	// 90
	LDY,	LDA,	LDX,	LAX,	LDY,	LDA,	LDX,	LAX,	TAY,	LDA,	TAX,	LAX,	LDY,	LDA,	LDX,	LAX,	// a0
	BCS,	LDA,	KIL,	LAX,	LDY,	LDA,	LDX,	LAX,	CLV,	LDA,	TSX,	LAS,	LDY,	LDA,	LDX,	LAX,	// b0
	CPY,	CMP,	NOP,	DCP,	CPY,	CMP,	DEC,	DCP,	INY,	CMP,	DEX,	AXS,	CPY,	CMP,	DEC,	DCP,	// c0
	BNE,	CMP,	KIL,	DCP,	NOP,	CMP,	DEC,	DCP,	CLD,	CMP,	NOP,	DCP,	NOP,	CMP,	DEC,	DCP,	// d0
	CPX,	SBC,	NOP,	ISC,	CPX,	SBC,	INC,	ISC,	INX,	SBC,	NOP,	SBC,	CPX,	SBC,	INC,	ISC,	// e0
	BEQ,	SBC,	KIL,	ISC,	NOP,	SBC,	INC,	ISC,	SED,	SBC,	NOP,	ISC,	NOP,	SBC,	INC,	ISC	// f0
};
assign opcode = LUT_op[ins];

Addressing LUT_addr[256];
assign LUT_addr = '{
//	+00	+01	+02	+03	+04	+05	+06	+07	+08	+09	+0a	+0b	+0c	+0d	+0e	+0f
	Imp,	IzX,	Imp,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Abs,	Abs,	Abs,	Abs,	// 00
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpX,	ZpX,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbX,	AbX,	// 10
	Abs,	IzX,	Imp,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Abs,	Abs,	Abs,	Abs,	// 20
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpX,	ZpX,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbX,	AbX,	// 30
	Imp,	IzX,	Imp,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Abs,	Abs,	Abs,	Abs,	// 40
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpX,	ZpX,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbX,	AbX,	// 50
	Imp,	IzX,	Imp,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Ind,	Abs,	Abs,	Abs,	// 60
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpX,	ZpX,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbX,	AbX,	// 70
	Imm,	IzX,	Imm,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Abs,	Abs,	Abs,	Abs,	// 80
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpY,	ZpY,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbY,	AbY,	// 90
	Imm,	IzX,	Imm,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Abs,	Abs,	Abs,	Abs,	// a0
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpY,	ZpY,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbY,	AbY,	// b0
	Imm,	IzX,	Imm,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Abs,	Abs,	Abs,	Abs,	// c0
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpX,	ZpX,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbX,	AbX,	// d0
	Imm,	IzX,	Imm,	IzX,	Zp,	Zp,	Zp,	Zp,	Imp,	Imm,	Imp,	Imm,	Abs,	Abs,	Abs,	Abs,	// e0
	Rel,	IzY,	Imp,	IzY,	ZpX,	ZpX,	ZpX,	ZpX,	Imp,	AbY,	Imp,	AbY,	AbX,	AbX,	AbX,	AbX	// f0
};
assign mode = LUT_addr[ins];

logic [1:0] bytes;
assign pc_bytes = bytes;

always_comb
begin
	bytes = 2'h0;
	case (mode)
	Imp:	bytes = 2'h1;
	Imm:	bytes = 2'h2;
	Ind:	bytes = 2'h3;
	IzX:	bytes = 2'h2;
	IzY:	bytes = 2'h2;
	Zp:	bytes = 2'h2;
	ZpX:	bytes = 2'h2;
	ZpY:	bytes = 2'h2;
	Abs:	bytes = 2'h3;
	AbX:	bytes = 2'h3;
	AbY:	bytes = 2'h3;
	Rel:	bytes = 2'h2;
	endcase
end

endmodule
