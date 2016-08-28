`include "config.h"
import typepkg::*;

module apu (
	sys_if sys,
	sysbus_if sysbus,
	output logic [7:0] out
);

logic en;
assign en = (sysbus.addr & ~(`APU_SIZE - 1)) == `APU_BASE;

logic [7:0] sel;
demux #(.N(3)) d0 (.oe(en), .sel(sysbus.addr[4:2]), .q(sel));

logic [3:0] pulse[2];
apu_pulse p0 (.sel(sel[0]), .out(pulse[0]), .*);
apu_pulse p1 (.sel(sel[1]), .out(pulse[1]), .*);

logic [3:0] triangle;
assign triangle = 4'b0;

logic [3:0] noise;
assign noise = 4'b0;

logic [6:0] dmc;
assign dmc = 7'b0;

logic [7:0] mix;
apu_mixer mix0 (.out(mix), .*);
assign out = mix;

endmodule
