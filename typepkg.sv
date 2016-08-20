package typepkg;

parameter BOOTROM_N		= 8;
parameter BOOTROM_SIZE	= (2 ** BOOTROM_N);
parameter ADDR_N			= 16;
parameter PERIPHS_N		= 8;
parameter ADDR_MAP_N		= (ADDR_N - PERIPHS_N);
parameter PERIPH_N		= 2;
parameter PERIPH_MAP_N	= (PERIPHS_N - PERIPH_N);
parameter DATA_N			= 8;

typedef enum {
	// Arithmetic operations
	ADC, SBC, AND, ORA, EOR,
	// Shifting operations
	ASL, LSR, ROL, ROR,
	// Increment & decrement operations
	INC, INX, INY,
	DEC, DEX, DEY,
	// Testing operations
	BIT, CMP, CPX, CPY,
	// Branching operations
	BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS,
	// Jumping operations
	JMP, JSR, RTI, RTS,
	// Status register operations
	SEC, SED, SEI, CLC, CLD, CLI, CLV,
	// Register transfer operations
	TAX, TAY, TSX, TXA, TXS, TYA,
	// Memory load & store operations
	STA, STX, STY,
	LDA, LDX, LDY,
	// Stack operations
	PHA, PHP, PLA, PLP,
	// Miscellaneous operations
	BRK, NOP,
	// Illegal opcodes
	SLO, RLA, SRE, RRA, SAX, LAX, DCP, ISC, ANC, ALR, ARR, XAA, AXS, AHX, SHY, SHX, TAS, LAS, KIL
} Opcode;

// Implied, Immediate, Indirect(+X/Y), Zero page(+X/Y), Absolute(+X/Y), Relative
typedef enum {Imp, Imm, Ind, IndX, IndY, Zpg, ZpgX, ZpgY, Abs, AbsX, AbsY, Rlt} Addressing;

endpackage
