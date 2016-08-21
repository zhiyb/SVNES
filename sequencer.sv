`include "config.h"
import typepkg::*;

module sequencer (
	sys_if sys,
	
	// Instruction infomation
	input Opcode opcode,
	input Addressing mode,
	
	// Bus control
	output logic bus_we, bus_oe,
	
	// Program counter
	pc_addr_oe, pc_oe,
	pc_inc, pc_next,
	
	// Instruction register
	ins_we,
	
	// Registers
	acc_we, acc_oe,
	x_we, x_oe,
	y_we, y_oe,
	sp_we, sp_oe,
	
	// ALU input select
	alu_a_bus, alu_a_con,
	alu_b_bus, alu_b_con,
	
	// ALU input constants select
	Constants alu_a_con_sel, alu_b_con_sel,
	
	// ALU function select
	output ALUFunc alu_func
);

enum {Reset, Fetch, Decode, Execute} state, state_next;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		state <= Fetch;
	else
		state <= state_next;

always_comb
begin
	bus_we = 1'b0;
	bus_oe = 1'b0;
	pc_addr_oe = 1'b0;
	pc_oe = 1'b0;
	pc_inc = 1'b0;
	pc_next = 1'b0;
	ins_we = 1'b0;
	acc_we = 1'b0;
	acc_oe = 1'b0;
	x_we = 1'b0;
	x_oe = 1'b0;
	y_we = 1'b0;
	y_oe = 1'b0;
	sp_we = 1'b0;
	sp_oe = 1'b0;
	alu_a_bus = 1'b0;
	alu_a_con = 1'b1;		// Use constants to minimise dynamic power consumption
	alu_a_con_sel = Con0;
	alu_b_bus = 1'b0;
	alu_b_con = 1'b1;
	alu_b_con_sel = Con0;
	alu_func = ALUAdd;
	state_next = state;
	case (state)
	Fetch: begin
		bus_oe = 1'b1;
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		ins_we = 1'b1;
		state_next = Decode;
	end
	Decode: begin
		if (mode == Imm) begin
			bus_oe = 1'b1;
			pc_addr_oe = 1'b1;
			pc_inc = 1'b1;
			state_next = Fetch;
			case (opcode)
			LDA: begin
				alu_a_bus = 1'b1;
				alu_a_con = 1'b0;
				acc_we = 1'b1;
			end
			ADC: begin
				acc_oe = 1'b1;
				alu_a_con = 1'b0;
				alu_b_bus = 1'b1;
				alu_b_con = 1'b0;
				acc_we = 1'b1;
			end
			endcase
		end
	end
	Execute: begin
	end
	endcase
end

endmodule
