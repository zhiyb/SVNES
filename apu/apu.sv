`include "config.h"
import typepkg::*;

module apu (
	sys_if sys,
	sysbus_if sysbus,
	output logic out
);

logic en;
assign en = sysbus.addr & ~(`APU_SIZE - 1) == `APU_BASE;

logic [7:0] sel;
demux #(.N(3)) d0 (.oe(en), .sel(sysbus.addr[4:2]), .q(sel));

logic pulse[2];
apu_pulse p0 (.sel(sel[0]), .out(pulse[0]), .*);
apu_pulse p1 (.sel(sel[1]), .out(pulse[1]), .*);

endmodule
