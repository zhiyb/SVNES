`include "config.h"

package typepkg;

typedef logic [`DATA_N - 1:0] dataLogic;

// Opcodes
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

// Addressing modes
// Implied, Immediate, Indirect(+X/Y), Zero page(+X/Y), Absolute(+X/Y), Relative
typedef enum {Imp, Imm, Ind, IndX, IndY, Zpg, ZpgX, ZpgY, Abs, AbsX, AbsY, Rlt} Addressing;

endpackage
