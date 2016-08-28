`include "config.h"
import typepkg::*;

module apu_pulse (
	sys_if sys,
	sysbus_if sysbus,
	input logic sel,
	output logic [3:0] out
);

logic we, oe;
assign we = sel & sysbus.we;
assign oe = sel & ~sysbus.we;

dataLogic regs[4];
assign sysbus.data = oe ? regs[sysbus.addr[1:0]] : {`DATA_N{1'bz}};

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		for (int i = 0; i != 4; i++)
			regs[i] <= {`DATA_N{1'b0}};
	end else if (we) begin
		regs[sysbus.addr[1:0]] <= sysbus.data;
	end

assign out = 4'b0;

endmodule
