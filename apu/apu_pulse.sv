`include "config.h"
import typepkg::*;

module apu_pulse (
	sys_if sys,
	sysbus_if sysbus,
	input logic apuclk, hframe,
	input logic sel, en,
	output logic act,
	output logic [3:0] out
);

logic [3:0] audio;
assign out = en ? audio : 4'b0;

// Registers

logic we, oe;
assign we = sel & sysbus.we;
assign oe = sel & ~sysbus.we;

dataLogic regs[4];
//assign sysbus.data = oe ? regs[sysbus.addr[1:0]] : {`DATA_N{1'bz}};

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		for (int i = 0; i != 4; i++)
			regs[i] <= {`DATA_N{1'b0}};
	end else if (we) begin
		regs[sysbus.addr[1:0]] <= sysbus.data;
	end

// Separation of registers

logic [1:0] duty;
assign duty = regs[0][7:6];

logic lc_halt;
assign lc_halt = regs[0][5];

logic vol_con;
assign vol_con = regs[0][4];

logic [3:0] env_period;
assign env_period = regs[0][3:0];

logic swp_en;
assign swp_en = regs[1][7];

logic [2:0] swp_period;
assign swp_period = regs[1][6:4];

logic swp_neg;
assign swp_neg = regs[1][3];

logic [2:0] swp_shift;
assign swp_shift = regs[1][2:0];

logic [10:0] timer;
assign timer = {regs[3][2:0], regs[2]};

logic [4:0] lc_load;
assign lc_load = regs[3][7:3];

// Length counter

logic load_lc, load_lc_cpu;
always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		load_lc_cpu <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		load_lc_cpu <= 1'b1;
	else if (load_lc)
		load_lc_cpu <= 1'b0;

logic gate_lc;
assign act = gate_lc;

logic [7:0] cnt, cnt_load;
apu_rom_length rom0 (.address(lc_load), .clock(sys.nclk), .q(cnt_load));

always_ff @(posedge hframe, negedge sys.n_reset)
	if (~sys.n_reset) begin
		cnt <= 8'b0;
		load_lc <= 1'b0;
		gate_lc <= 1'b0;
	end else begin
		load_lc <= load_lc_cpu;
		if (cnt == 8'b0)
			gate_lc <= 1'b0;
		else
			gate_lc <= 1'b1;
		if (~en)
			cnt <= 8'b0;
		else if (load_lc_cpu)
			cnt <= cnt_load;
		else if (~lc_halt && cnt != 8'b0)
			cnt <= cnt - 8'b1;
	end

// Output generation

logic gate;
assign gate = en && gate_lc;

logic aout;
counter #(.n($clog2(2033 - 1))) c0 (.top(2033 - 1), .clk(apuclk), .n_reset(sys.n_reset), .out(aout));

assign audio = gate ? {4{aout}} : 4'b0;

endmodule
