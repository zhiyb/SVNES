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
	pc_addr_oe, pc_inc,
	
	// Instruction register
	ins_we,
	
	// ALU buses controls
	output alu_bus_a_t abus_a,
	output alu_bus_b_t abus_b,
	output alu_bus_o_t abus_o,
	
	// ALU function select
	output ALUFunc alu_func,
	
	// Status register
	output dataLogic p_mask, p_set, p_clr
);

enum {Reset, Fetch, Decode, Execute} state, state_next;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		state <= Fetch;
	else
		state <= state_next;

logic execute;
always_comb
begin
	bus_we = 1'b0;
	bus_oe = 1'b0;
	pc_addr_oe = 1'b0;
	pc_inc = 1'b0;
	ins_we = 1'b0;
	
	abus_a.bus = 1'b0;
	abus_a.con = 1'b1;	// Use constants to minimise switching
	abus_a.consel = Con0;
	abus_a.acc = 1'b0;
	abus_a.x = 1'b0;
	abus_a.y = 1'b0;
	abus_a.p = 1'b0;
	abus_a.sp = 1'b0;
	abus_a.pcl = 1'b0;
	abus_a.pch = 1'b0;
	
	abus_b.bus = 1'b0;
	abus_b.con = 1'b1;	// Use constants to minimise switching
	abus_b.consel = Con0;
	
	abus_o.acc = 1'b0;
	abus_o.x = 1'b0;
	abus_o.y = 1'b0;
	abus_o.sp = 1'b0;
	abus_o.pcl = 1'b0;
	abus_o.pch = 1'b0;
	
	alu_func = ALUAdd;
	p_mask = 'h0;
	p_mask[`STATUS_R] = 1'b1;
	p_set = 'h0;
	p_clr = 'h0;
	state_next = state;
	
	execute = 1'b0;
	case (state)
	Fetch: begin
		bus_oe = 1'b1;
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		ins_we = 1'b1;
		state_next = Decode;
	end
	Decode: begin
		bus_oe = 1'b1;
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		if (mode == Imm) begin
			state_next = Fetch;
			execute = 1'b1;
		end
	end
	Execute: begin
	end
	endcase
	
	if (execute)
		case (opcode)
		ADC: begin
			abus_a.acc = 1'b1;
			abus_a.con = 1'b0;
			abus_b.bus = 1'b1;
			abus_b.con = 1'b0;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
			p_mask[`STATUS_V] = 1'b1;
		end
		SBC: begin
			alu_func = ALUSub;
			abus_a.acc = 1'b1;
			abus_a.con = 1'b0;
			abus_b.bus = 1'b1;
			abus_b.con = 1'b0;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
			p_mask[`STATUS_V] = 1'b1;
		end
		LDA: begin
			abus_a.bus = 1'b1;
			abus_a.con = 1'b0;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		endcase
end

endmodule
