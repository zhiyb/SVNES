`include "config.h"

interface sys_if (
	input logic clk, nclk, n_reset
);
endinterface

interface sysbus_if (
	output wire rdy,
	input logic we,
	inout wire [15:0] addr,
	inout wire [7:0] data
);
endinterface

interface periphbus_if (
	input logic we,
	input logic [`PERIPH_N - 1:0] addr,
	inout wire [7:0] data
);
endinterface
