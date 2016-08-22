`include "config.h"
import typepkg::*;

interface sys_if (
	input logic clk, n_reset
);
endinterface

interface sysbus_if (
	input logic we,
	inout wire [`ADDR_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);
endinterface

interface regbus_if (
	input logic we, oe,
	output dataLogic data,
	input dataLogic in,
	output wire [`DATA_N - 1:0] out
);
endinterface

interface periphbus_if (
	input logic we,
	input logic [`PERIPH_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);
endinterface
