`include "config.h"
import typepkg::*;

module cpu (
	// Clock, reset and buses
	input logic clk, n_reset,
	output logic bus_we, bus_oe,
	output wire [`ADDR_N - 1:0] bus_addr,
	inout wire [`DATA_N - 1:0] bus_data
);

// Program counter
logic pc_addr_oe;
logic [1:0] pc_bytes;
pc pc0 (.*);

// Instruction register
logic [`DATA_N - 1:0] ins;
logic ins_we;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		ins <= 'b0;
	else if (ins_we)
		ins <= bus_data;

// Instruction decoder
Opcode opcode;
Addressing mode;
idec idec0 (.*);

// Control sequencer
sequencer seq0 (.*);

endmodule
