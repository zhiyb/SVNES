`include "defines.h"
import typepkg::*;

module cpu (
	sys_if sys,
	input logic rdy,
	output logic we, fetch,
	output wire [15:0] addr,
	inout wire [7:0] data,
	input logic irq, nmi
);

// Instruction register
logic [7:0] ins;
logic ins_we;
logic int_evnt;
register ins0 (
	.we(ins_we), .oe(1'b0),
	.in(int_evnt ? 8'h0 : data), .out(), .data(ins), .*);

// ALU
wire [7:0] alu_in_a, alu_in_b;
logic [7:0] alu_out;
ALUFunc alu_func;
logic alu_cin, alu_cinclr;
logic alu_cout, alu_sign, alu_zero, alu_ovf;
alu alu0 (.*);

alu_bus_a_t abus_a;
assign alu_in_a = abus_a.con ? 8'h0 : 8'bz;

alu_bus_b_t abus_b;
assign alu_in_b = abus_b.bus ? data : 8'bz;
assign alu_in_b = abus_b.con ? 8'h1 : 8'bz;

alu_bus_o_t abus_o;
assign data = abus_o.bus ? alu_out : 8'bz;

// Registers
logic [7:0] acc;
register acc0 (.we(abus_o.acc), .oe(abus_a.acc), .in(alu_out), .out(alu_in_a), .data(acc), .*);

logic [7:0] x;
register x0 (.we(abus_o.x), .oe(abus_a.x), .in(alu_out), .out(alu_in_a), .data(x), .*);

logic [7:0] y;
register y0 (.we(abus_o.y), .oe(abus_a.y), .in(alu_out), .out(alu_in_a), .data(y), .*);

// Status register
logic [7:0] p, p_in, p_din;
logic [7:0] p_mask, p_set, p_clr;
logic p_brk, p_int;
assign p_brk = 1'b0, p_int = 1'b0;
assign p_in = {alu_sign, alu_ovf, 1'b1, p_brk, 1'b0, p_int, alu_zero, alu_cout};
assign p_din = abus_o.p ? alu_out : ((~p_mask & p) | (p_mask & p_in) | p_set) & ~p_clr;
assign alu_cin = p[`STATUS_C];
register #(.reset((8'h01 << `STATUS_R) | (8'h01 << `STATUS_I))) p0 (
	.we(1'b1), .oe(abus_a.p),
	.in(p_din | (8'h01 << `STATUS_R)),
	.out(alu_in_a), .data(p), .*);

logic p_oe;
assign data = p_oe ? p : 8'bz;

// Stack pointer
logic [7:0] sp;
logic sp_addr_oe;
register sp0 (.we(abus_o.sp), .oe(abus_a.sp), .in(alu_out), .out(alu_in_a), .data(sp), .*);
assign addr = sp_addr_oe ? {8'h1, sp} : 16'bz;

// Data latch registers
logic [7:0] dl;
register dl0 (.we(rdy), .oe(abus_a.dl), .in(data), .out(alu_in_a), .data(dl), .*);
assign alu_in_b = abus_b.dl ? dl : 8'bz;
logic dl_sign;
assign dl_sign = dl[7];

logic [7:0] adl;
register adl0 (
	.we(abus_o.adl), .oe(abus_a.adl),
	.in(alu_out), .out(alu_in_a), .data(adl), .*);

logic [7:0] adh;
logic adh_bus;
logic [7:0] adh_in;
assign adh_in = abus_o.adh ? alu_out : data;
register adh0 (
	.we(abus_o.adh | adh_bus), .oe(abus_a.adh),
	.in(adh_in), .out(alu_in_a), .data(adh), .*);

logic ad_addr_oe;
assign addr = ad_addr_oe ? {adh, adl} : 16'bz;

// Program counter
logic [15:0] pc;
logic pc_addr_oe;
logic pc_inc, pc_load, pc_int;
logic [15:0] int_addr;
pc pc0 (
	.oel(abus_a.pcl), .oeh(abus_a.pch),
	.wel(abus_o.pcl), .weh(abus_o.pch),
	.in(alu_out), .out(alu_in_a),
	.load({data, dl}), .data(pc), .*);

logic pcl_oe, pch_oe;
assign data = pcl_oe ? pc[7:0] : 8'bz;
assign data = pch_oe ? pc[15:8] : 8'bz;

// Interrupt logic
logic int_handled;
interrupts int0 (.i(p[`STATUS_I]), .*);

// Instruction decoder
Opcode opcode;
Addressing mode;
idec idec0 (.pc_bytes(), .*);

// Control sequencer
sequencer seq0 (.bus_rdy(rdy), .bus_we(we), .*);

endmodule
