`include "config.h"

module registers (
	input logic clk, n_reset,
	input logic reg_we,
	input logic [`REG_ADDR_N - 1:0] reg_src[2], reg_dst,
	output logic [`DATA_N - 1:0] reg_data[2],
	input logic [`DATA_N - 1:0] bus_data
);

logic [`DATA_N - 1:0] regs[`REG_N];

assign reg_data[0] = regs[reg_src[0]];
assign reg_data[1] = regs[reg_src[1]];

always_ff @(posedge clk)
	if (reg_we)
		regs[reg_dst] <= bus_data;

endmodule
