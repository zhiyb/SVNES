`include "config.h"
import typepkg::*;

module cpu (
	sys_if sys,
	output logic we,
	output wire [`ADDR_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);

sysbus_if sysbus (.*);

// Instruction register
dataLogic ins;
logic ins_we;
regbus_if ins0bus (.we(ins_we), .oe(1'b0), .in(sysbus.data), .out(), .data(ins));
register ins0 (.regbus(ins0bus), .*);

// ALU
wire [`DATA_N - 1:0] alu_in_a, alu_in_b;
dataLogic alu_out;
ALUFunc alu_func;
logic alu_cin, alu_cout, alu_sign, alu_zero, alu_ovf;
alu alu0 (.*);

alu_bus_a_t abus_a;
assign alu_in_a = abus_a.bus ? sysbus.data : 'bz;
constants con_a (.oe(abus_a.con), .sel(abus_a.consel), .out(alu_in_a));

alu_bus_b_t abus_b;
assign alu_in_b = abus_b.bus ? sysbus.data : 'bz;
constants con_b (.oe(abus_b.con), .sel(abus_b.consel), .out(alu_in_b));

alu_bus_o_t abus_o;

// Registers
dataLogic acc;
regbus_if acc0bus (.we(abus_o.acc), .oe(abus_a.acc), .in(alu_out), .out(alu_in_a), .data(acc));
register acc0 (.regbus(acc0bus), .*);

dataLogic x;
regbus_if x0bus (.we(abus_o.x), .oe(abus_a.x), .in(alu_out), .out(alu_in_a), .data(x));
register x0 (.regbus(x0bus), .*);

dataLogic y;
regbus_if y0bus (.we(abus_o.y), .oe(abus_a.y), .in(alu_out), .out(alu_in_a), .data(y));
register y0 (.regbus(y0bus), .*);

// Status register
dataLogic p, p_in, p_din;
dataLogic p_mask, p_set, p_clr;
logic p_brk, p_int;
assign p_brk = 1'b0, p_int = 1'b0;
assign p_in = {alu_sign, alu_ovf, 1'b1, p_brk, 1'b0, p_int, alu_zero, alu_cout};
assign p_din = ((~p_mask & p) | (p_mask & p_in) | p_set) & ~p_clr;
assign alu_cin = p[`STATUS_C];
regbus_if p0bus (.we(1'b1), .oe(abus_a.p), .in(p_din), .out(alu_in_a), .data(p));
register p0 (.regbus(p0bus), .*);

// Stack pointer
dataLogic sp;
regbus_if sp0bus (.we(abus_o.sp), .oe(abus_a.sp), .in(alu_out), .out(alu_in_a), .data(sp));
register sp0 (.regbus(sp0bus), .*);

// Program counter
logic pc_addr_oe;
logic pc_inc;
pc pc0 (
	.oel(abus_a.pcl), .oeh(abus_a.pch),
	.wel(abus_o.pcl), .weh(abus_o.pch),
	.in(alu_out), .out(alu_in_a),
	.*);

// Instruction decoder
Opcode opcode;
Addressing mode;
idec idec0 (.pc_bytes(), .*);

// Control sequencer
sequencer seq0 (.bus_we(we), .bus_oe(oe), .*);

endmodule
