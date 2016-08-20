`include "config.h"
import typepkg::*;

module cpu (
	sys_if sys,
	output logic we, oe,
	output wire [`ADDR_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);

sysbus_if sysbus (.*);

// Program counter
logic pc_addr_oe;
logic pc_next;
logic [1:0] pc_bytes;
pc pc0 (.*);

// Instruction register
dataLogic ins;
logic ins_we;
register ins0 (.we(ins_we), .oe(1'b0), .data(ins), .*);

// Registers
dataLogic acc;
logic acc_we, acc_oe;
register acc0 (.we(acc_we), .oe(acc_oe), .data(acc), .*);

// Instruction decoder
Opcode opcode;
Addressing mode;
idec idec0 (.*);

// Control sequencer
sequencer seq0 (.bus_we(we), .bus_oe(oe), .*);

endmodule
