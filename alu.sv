`include "config.h"
import typepkg::*;

module alu (
	input wire [`DATA_N - 1:0] alu_in_a, alu_in_b,
	output dataLogic alu_out,
	input logic cin,
	output logic sign, zero, cout, ovf,
	input ALUFunc alu_func
);

assign sign = alu_out[`DATA_N - 1];
assign zero = alu_out == 'h0;

always_comb
begin
	alu_out = 'b0;
	cout = 'b0;
	case (alu_func)
	ALUAdd:	{cout, alu_out} = alu_in_a + alu_in_b + cin;
	ALUSub:	{cout, alu_out} = 'b0;
	endcase
end

endmodule
