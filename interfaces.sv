`include "config.h"

interface sys_if (
	input logic clk, n_reset
);
endinterface

interface sysbus_if (
	input logic we, oe,
	inout wire [`ADDR_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);
endinterface

interface periphbus_if (
	input logic we, oe,
	input logic [`PERIPH_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);
endinterface
