`include "config.h"
import typepkg::*;

module sequencer (
	sys_if sys,
	
	// Instruction infomation
	input Opcode opcode,
	input Addressing mode,
	
	// Bus control
	output logic bus_we, dbg,
	
	// Program counter
	pc_addr_oe, pc_inc, pc_load,
	
	// Data latch registers
	input logic dl_sign,
	output logic dl_addr_oe, dlh_clr,
	
	// Stack register
	sp_addr_oe,
	
	// Instruction register
	ins_we,
	
	// ALU flags
	input logic alu_cin, alu_cout, alu_sign, alu_zero, alu_ovf,
	output logic alu_cinclr,
	
	// ALU buses controls
	output alu_bus_a_t abus_a,
	output alu_bus_b_t abus_b,
	output alu_bus_o_t abus_o,
	
	// ALU function select
	output ALUFunc alu_func,
	
	// Status register
	input dataLogic p,
	output dataLogic p_mask, p_set, p_clr
);

enum int unsigned {JumpL, JumpH, Branch, BranchOVF, Fetch, Decode, ReadH, Execute, Store, Push, Pull} state, state_next;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		state <= JumpL;
	else
		state <= state_next;

logic execute, branch;
always_comb
begin
	bus_we = 1'b0;
	pc_addr_oe = 1'b0;
	dl_addr_oe = 1'b0;
	sp_addr_oe = 1'b0;
	pc_inc = 1'b0;
	pc_load = 1'b0;
	ins_we = 1'b0;
	dlh_clr = 1'b0;
	
	abus_a.bus = 1'b1;
	abus_a.con = 1'b0;
	abus_a.acc = 1'b0;
	abus_a.x = 1'b0;
	abus_a.y = 1'b0;
	abus_a.p = 1'b0;
	abus_a.sp = 1'b0;
	abus_a.dll = 1'b0;
	abus_a.dlh = 1'b0;
	abus_a.pcl = 1'b0;
	abus_a.pch = 1'b0;
	
	abus_b.bus = 1'b1;
	abus_b.con = 1'b0;
	abus_b.dl = 1'b0;
	
	abus_o.bus = 1'b0;
	abus_o.acc = 1'b0;
	abus_o.x = 1'b0;
	abus_o.y = 1'b0;
	abus_o.p = 1'b0;
	abus_o.sp = 1'b0;
	abus_o.dl = 1'b0;
	abus_o.dll = 1'b0;
	abus_o.dlh = 1'b0;
	abus_o.pcl = 1'b0;
	abus_o.pch = 1'b0;
	
	alu_func = ALUTXB;
	alu_cinclr = 1'b0;
	p_mask = 'h0;
	p_mask[`STATUS_R] = 1'b1;
	p_set = 'h0;
	p_clr = 'h0;
	state_next = state;
	
	dbg = state == Fetch;
	
	case (opcode)
	// Branching operations
	BCC:	branch = ~p[`STATUS_C];
	BCS:	branch = p[`STATUS_C];
	BNE:	branch = ~p[`STATUS_Z];
	BEQ:	branch = p[`STATUS_Z];
	BPL:	branch = ~p[`STATUS_N];
	BMI:	branch = p[`STATUS_N];
	BVC:	branch = ~p[`STATUS_V];
	BVS:	branch = p[`STATUS_V];
	default:	branch = 1'b0;
	endcase
	
	execute = 1'b0;
	case (state)
	Fetch:	begin
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		ins_we = 1'b1;
		state_next = Decode;
	end
	Decode:	begin
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		case (mode)
		Imp:	begin
			pc_inc = 1'b0;
			case (opcode)
			PHA, PHP:	begin
				execute = 1'b1;
				pc_addr_oe = 1'b0;
				state_next = Push;
			end
			PLA, PLP:	begin
				alu_func = ALUSUB;	// SP - 1 => SP
				alu_cinclr = 1'b1;
				abus_a.bus = 1'b0;
				abus_a.sp = 1'b1;
				abus_b.bus = 1'b0;
				abus_b.con = 1'b1;
				abus_o.sp = 1'b1;
				state_next = Pull;
			end
			default:	begin
				execute = 1'b1;
				state_next = Fetch;
			end
			endcase
		end
		Imm:	begin
			state_next = Fetch;
			execute = 1'b1;
		end
		Zp:	begin
			alu_func = ALUTXB;	// BUS => DLL
			abus_b.bus = 1'b1;
			abus_o.dll = 1'b1;
			dlh_clr = 1'b1;		// 0 => DLH
			abus_o.dlh = 1'b1;
			state_next = Execute;
		end
		ZpX:	begin
		end
		Abs:	begin
			alu_func = ALUTXB;	// BUS => DLL
			abus_b.bus = 1'b1;
			abus_o.dll = 1'b1;
			state_next = ReadH;
		end
		Rel: begin
			if (branch) begin
				alu_func = ALUTXB;	// BUS => DL
				abus_b.bus = 1'b1;
				abus_o.dl = 1'b1;
				state_next = Branch;
			end else
				state_next = Fetch;
		end
		default:	;
		endcase
	end
	Branch:	begin
		pc_addr_oe = 1'b1;
		alu_func = ALUADD;	// PCL + DL => PCL
		alu_cinclr = 1'b1;
		abus_a.bus = 1'b0;
		abus_a.pcl = 1'b1;
		abus_b.bus = 1'b0;
		abus_b.dl = 1'b1;
		abus_o.pcl = 1'b1;
		if (alu_cout ^ dl_sign)
			state_next = BranchOVF;
		else
			state_next = Fetch;
	end
	BranchOVF:	begin
		pc_addr_oe = 1'b1;
		alu_func = dl_sign ? ALUSUB : ALUADD;	// PCH +/- 1 => PCH
		alu_cinclr = 1'b1;
		abus_a.bus = 1'b0;
		abus_a.pch = 1'b1;
		abus_b.bus = 1'b0;
		abus_b.con = 1'b1;
		abus_o.pch = 1'b1;
		state_next = Fetch;
	end
	ReadH:	begin
		pc_addr_oe = 1'b1;
		alu_func = ALUTXB;	// BUS => DLH
		abus_b.bus = 1'b1;
		abus_o.dlh = 1'b1;
		if (opcode == JMP || opcode == JSR) begin
			pc_load = 1'b1;
			state_next = Fetch;
		end else begin
			pc_inc = 1'b1;
			state_next = Execute;
		end
	end
	Execute:	begin
		dl_addr_oe = 1'b1;
		execute = 1'b1;
		case (opcode)
		ASL, LSR,
		ROL, ROR,
		INC, DEC:	state_next = Store;
		default:		state_next = Fetch;
		endcase
	end
	Store:	begin
		dl_addr_oe = 1'b1;
		bus_we = 1'b1;
		alu_func = ALUTXB;	// DL => BUS
		abus_b.bus = 1'b0;
		abus_b.dl = 1'b1;
		abus_o.bus = 1'b1;
		state_next = Fetch;
	end
	JumpL:	begin
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		alu_func = ALUTXB;	// BUS => DLL
		abus_b.bus = 1'b1;
		abus_o.dll = 1'b1;
		state_next = JumpH;
	end
	JumpH:	begin
		pc_addr_oe = 1'b1;
		pc_load = 1'b1;
		alu_func = ALUTXB;	// BUS => DLH
		abus_b.bus = 1'b1;
		abus_o.dlh = 1'b1;
		state_next = Fetch;
	end
	Push:	begin
		pc_addr_oe = 1'b1;
		alu_func = ALUADD;	// SP + 1 => SP
		alu_cinclr = 1'b1;
		abus_a.bus = 1'b0;
		abus_a.sp = 1'b1;
		abus_b.bus = 1'b0;
		abus_b.con = 1'b1;
		abus_o.sp = 1'b1;
		state_next = Fetch;
	end
	Pull:	begin
		execute = 1'b1;
		state_next = Fetch;
	end
	endcase
	
	if (execute)
		case (opcode)
		// Arithmetic operations
		ADC:	begin
			alu_func = ALUADD;	// ACC + BUS + C => ACC
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
			p_mask[`STATUS_V] = 1'b1;
		end
		SBC:	begin
			alu_func = ALUSUB;	// ACC - BUS - C => ACC
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
			p_mask[`STATUS_V] = 1'b1;
		end
		// Compare operations
		BIT:	begin
			alu_func = ALUBIT;	// ACC BIT BUS => P
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_V] = 1'b1;
		end
		CMP:	begin
			alu_func = ALUSUB;	// ACC - BUS => P
			alu_cinclr = 1'b1;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		CPX:	begin
			alu_func = ALUSUB;	// X - BUS => P
			alu_cinclr = 1'b1;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_b.bus = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		CPY:	begin
			alu_func = ALUSUB;	// Y - BUS => P
			alu_cinclr = 1'b1;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_b.bus = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		// Logical operations
		AND:	begin
			alu_func = ALUAND;	// ACC AND BUS => ACC
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		ORA:	begin
			alu_func = ALUORA;	// ACC ORA BUS => ACC
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		EOR:	begin
			alu_func = ALUEOR;	// ACC EOR BUS => ACC
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		// Shifting operations
		ASL:	begin
			alu_func = ALUROL;
			alu_cinclr = 1'b1;
			if (mode == Imp) begin	// ASL ACC => ACC
				abus_a.bus = 1'b0;
				abus_a.acc = 1'b1;
				abus_o.acc = 1'b1;
			end else begin				// ASL BUS => DL
				abus_a.bus = 1'b1;
				abus_o.dl = 1'b1;
			end
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		LSR:	begin
			alu_func = ALUROR;
			alu_cinclr = 1'b1;
			if (mode == Imp) begin	// LSR ACC => ACC
				abus_a.bus = 1'b0;
				abus_a.acc = 1'b1;
				abus_o.acc = 1'b1;
			end else begin				// LSR BUS => DL
				abus_a.bus = 1'b1;
				abus_o.dl = 1'b1;
			end
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		ROL:	begin
			alu_func = ALUROL;
			if (mode == Imp) begin	// ROL ACC => ACC
				abus_a.bus = 1'b0;
				abus_a.acc = 1'b1;
				abus_o.acc = 1'b1;
			end else begin				// ROL BUS => DL
				abus_a.bus = 1'b1;
				abus_o.dl = 1'b1;
			end
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		ROR:	begin
			alu_func = ALUROR;
			if (mode == Imp) begin	// ROR ACC => ACC
				abus_a.bus = 1'b0;
				abus_a.acc = 1'b1;
				abus_o.acc = 1'b1;
			end else begin				// ROR BUS => DL
				abus_a.bus = 1'b1;
				abus_o.dl = 1'b1;
			end
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		// Increment & decrement operations
		INC:	begin
			alu_func = ALUADD;	// BUS + 1 => DL
			abus_a.bus = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.dl = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		INX:	begin
			alu_func = ALUADD;	// X + 1 => X
			alu_cinclr = 1'b1;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		INY:	begin
			alu_func = ALUADD;	// Y + 1 => Y
			alu_cinclr = 1'b1;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		DEC:	begin
			alu_func = ALUSUB;	// BUS - 1 => DL
			abus_a.bus = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.dl = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		DEX:	begin
			alu_func = ALUSUB;	// X - 1 => X
			alu_cinclr = 1'b1;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		DEY:	begin
			alu_func = ALUSUB;	// Y - 1 => Y
			alu_cinclr = 1'b1;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		// Memory load
		LDA:	begin
			alu_func = ALUTXB;	// BUS => ACC
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		LDX:	begin
			alu_func = ALUTXB;	// BUS => X
			abus_b.bus = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		LDY:	begin
			alu_func = ALUTXB;	// BUS => Y
			abus_b.bus = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		// Memory store
		STA:	begin
			alu_func = ALUTXA;	// ACC => BUS
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.bus = 1'b1;
			bus_we = 1'b1;
		end
		STX:	begin
			alu_func = ALUTXA;	// X => BUS
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_o.bus = 1'b1;
			bus_we = 1'b1;
		end
		STY:	begin
			alu_func = ALUTXA;	// Y => BUS
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_o.bus = 1'b1;
			bus_we = 1'b1;
		end
		// Status register operations
		SEC:	p_set[`STATUS_C] = 1'b1;
		SED:	p_set[`STATUS_D] = 1'b1;
		SEI:	p_set[`STATUS_I] = 1'b1;
		CLC:	p_clr[`STATUS_C] = 1'b1;
		CLD:	p_clr[`STATUS_D] = 1'b1;
		CLI:	p_clr[`STATUS_I] = 1'b1;
		CLV:	p_clr[`STATUS_V] = 1'b1;
		// Register transfer operations
		TAX:	begin
			alu_func = ALUTXA;	// ACC => X
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TAY:	begin
			alu_func = ALUTXA;	// ACC => Y
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TSX:	begin
			alu_func = ALUTXA;	// SP => X
			abus_a.bus = 1'b0;
			abus_a.sp = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TXA:	begin
			alu_func = ALUTXA;	// A => ACC
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TXS:	begin
			alu_func = ALUTXA;	// X => SP
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_o.sp = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TYA:	begin
			alu_func = ALUTXA;	// Y => ACC
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		// Stack operations
		PHA:	begin
			alu_func = ALUTXA;	// ACC => BUS
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.bus = 1'b1;
			sp_addr_oe = 1'b1;
			bus_we = 1'b1;
		end
		PHP:	begin
			alu_func = ALUTXA;	// P => BUS
			abus_a.bus = 1'b0;
			abus_a.p = 1'b1;
			abus_o.bus = 1'b1;
			sp_addr_oe = 1'b1;
			bus_we = 1'b1;
		end
		PLA:	begin
			alu_func = ALUTXB;	// BUS => ACC
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			sp_addr_oe = 1'b1;
		end
		PLP:	begin
			alu_func = ALUTXB;	// BUS => P
			abus_b.bus = 1'b1;
			abus_o.p = 1'b1;
			sp_addr_oe = 1'b1;
		end
		default:	;
		endcase
end

endmodule
