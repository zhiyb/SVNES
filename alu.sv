`include "config.h"
import typepkg::*;

module alu (
	input wire [`DATA_N - 1:0] alu_in_a, alu_in_b,
	output dataLogic alu_out,
	input logic alu_cin,
	output logic alu_cout, alu_zero, alu_sign, alu_ovf,
	input ALUFunc alu_func
);

assign alu_zero = alu_out == 'h0;
assign alu_sign = alu_out[`DATA_N - 1];

logic as, bs, rs;
assign as = alu_in_a[`DATA_N - 1];
assign bs = alu_in_b[`DATA_N - 1];
assign rs = alu_out[`DATA_N - 1];
assign alu_ovf = ~(as ^ bs) && (as ^ rs);

always_comb
begin
	alu_out = 'b0;
	alu_cout = 'b0;
	case (alu_func)
	ALUAdd:	{alu_cout, alu_out} = alu_in_a + alu_in_b + alu_cin;
	ALUSub:	{alu_cout, alu_out} = 'b0;
	endcase
end

endmodule
