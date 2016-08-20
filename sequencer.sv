`include "config.h"
import typepkg::*;

module sequencer (
	// Clock and reset
	input logic clk, n_reset,
	
	// Bus control
	output logic bus_we, bus_oe,
	
	// Program counter fetching enable
	output logic pc_addr_oe,
	
	// Instruction write enable
	output logic ins_we,
	
	input Opcode opcode,
	input Addressing mode
);

enum {Fetch} state;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		state <= Fetch;
	else
		case (state)
			Fetch: begin
			end
		endcase

always_comb
begin
	bus_we = 1'b0;
	bus_oe = 1'b0;
	pc_addr_oe = 1'b0;
	ins_we = 1'b0;
	case (state)
	Fetch: begin
		bus_oe = 1'b1;
		pc_addr_oe = 1'b1;
		ins_we = 1'b1;
	end
	endcase
end

endmodule
