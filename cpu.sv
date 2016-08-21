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
logic pc_addr_oe, pc_oe;
logic pc_inc, pc_next;
logic [1:0] pc_bytes;
pc pc0 (.*);

// Instruction register
dataLogic ins;
logic ins_we;
regbus_if ins0bus (.we(ins_we), .oe(1'b0), .in(sysbus.data), .out(), .data(ins));
register ins0 (.regbus(ins0bus), .*);

// ALU
wire [`DATA_N - 1:0] alu_in_a, alu_in_b;
dataLogic alu_out;
ALUFunc alu_func;
logic cin, sign, zero, cout, ovf;
assign cin = 'b0;
alu alu0 (.*);

logic alu_a_bus, alu_a_con;
assign alu_in_a = alu_a_bus ? sysbus.data : 'bz;
Constants alu_a_con_sel;
constants con_a (.oe(alu_a_con), .sel(alu_a_con_sel), .out(alu_in_a));

logic alu_b_bus, alu_b_con;
assign alu_in_b = alu_b_bus ? sysbus.data : 'bz;
Constants alu_b_con_sel;
constants con_b (.oe(alu_b_con), .sel(alu_b_con_sel), .out(alu_in_b));

// Registers
dataLogic acc;
logic acc_we, acc_oe;
regbus_if acc0bus (.we(acc_we), .oe(acc_oe), .in(alu_out), .out(alu_in_a), .data(acc));
register acc0 (.regbus(acc0bus), .*);

dataLogic x;
logic x_we, x_oe;
regbus_if x0bus (.we(x_we), .oe(x_oe), .in(alu_out), .out(alu_in_a), .data(x));
register x0 (.regbus(x0bus), .*);

dataLogic y;
logic y_we, y_oe;
regbus_if y0bus (.we(y_we), .oe(y_oe), .in(alu_out), .out(alu_in_a), .data(y));
register y0 (.regbus(y0bus), .*);

dataLogic sp;
logic sp_we, sp_oe;
regbus_if sp0bus (.we(sp_we), .oe(sp_oe), .in(alu_out), .out(alu_in_a), .data(sp));
register sp0 (.regbus(sp0bus), .*);

// Instruction decoder
Opcode opcode;
Addressing mode;
idec idec0 (.*);

// Control sequencer
sequencer seq0 (.bus_we(we), .bus_oe(oe), .*);

endmodule
