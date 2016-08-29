`include "config.h"
import typepkg::*;

interface sys_if (
	input logic clk, nclk, n_reset
);
endinterface

interface sysbus_if (
	inout wire rdy,
	input logic we,
	inout wire [`ADDR_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);
endinterface

interface periphbus_if (
	input logic we,
	input logic [`PERIPH_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);
endinterface
