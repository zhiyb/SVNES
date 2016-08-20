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
	pc_addr_oe, pc_next,
	
	// Instruction register
	ins_we,
	
	// Accumulator
	acc_we, acc_oe
);

enum {Reset, Fetch, Execute} state, state_next;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		state <= Reset;
	else
		state <= state_next;

always_comb
begin
	bus_we = 1'b0;
	bus_oe = 1'b0;
	pc_addr_oe = 1'b0;
	pc_next = 1'b0;
	ins_we = 1'b0;
	acc_we = 1'b0;
	acc_oe = 1'b0;
	state_next = state;
	case (state)
	Reset: begin
		bus_oe = 1'b1;
		pc_addr_oe = 1'b1;
		ins_we = 1'b1;
		state_next = Fetch;
	end
	Fetch: begin
		bus_oe = 1'b1;
		pc_addr_oe = 1'b1;
		ins_we = 1'b1;
		pc_next = 1'b1;
		state_next = Fetch;
	end
	Execute: begin
		pc_next = 1'b1;
		state_next = Fetch;
	end
	endcase
end

endmodule
