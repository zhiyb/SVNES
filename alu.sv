`include "config.h"
import typepkg::*;

module alu (
	input wire [`DATA_N - 1:0] alu_in_a, alu_in_b,
	output dataLogic alu_out,
	input logic alu_cin,
	output logic alu_cout, alu_zero, alu_sign, alu_ovf,
	input ALUFunc alu_func
);

dataLogic a, b, out;
logic cin, cout;

assign alu_zero = out == 'h0;
assign alu_sign = out[`DATA_N - 1];

logic as, bs, rs;
assign as = a[`DATA_N - 1];
assign bs = b[`DATA_N - 1];
assign rs = out[`DATA_N - 1];
assign alu_ovf = ~(as ^ bs) && (as ^ rs);

always_comb
begin
	a = alu_in_a;
	b = alu_in_b;
	cin = alu_cin;
	out = 'h0;
	case (alu_func)
	ALUAdd:	{cout, out} = a + b + {{`DATA_N - 1{1'b0}}, cin};
	ALUSub:	begin
		b = ~b;
		{cout, out} = a + b + {{`DATA_N - 1{1'b0}}, ~cin};
		cout = ~cout;
	end
	endcase
	alu_out = out;
	alu_cout = cout;
end

endmodule
