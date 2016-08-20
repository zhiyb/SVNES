`include "config.h"

module register (
	sys_if sys,
	sysbus_if sysbus,
	// Read & write control
	input logic we, oe,
	output logic [`DATA_N - 1:0] data
);

assign sysbus.data = oe ? data : 'bz;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		data <= 'h0;
	else if (we)
		data <= sysbus.data;

endmodule
