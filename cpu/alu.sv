import typepkg::*;

module alu (
	input wire [7:0] alu_in_a, alu_in_b,
	output logic [7:0] alu_out,
	input logic alu_cin, alu_cinclr,
	output logic alu_cout, alu_zero, alu_sign, alu_ovf,
	input ALUFunc alu_func
);

logic [7:0] a, b, out;
logic cin, cout;

assign alu_zero = out == 'h0;
assign alu_sign = alu_func == ALUBIT ? b[7] : out[7];
assign alu_ovf = alu_func == ALUBIT ? b[6] : ~(a[7] ^ b[7]) && (a[7] ^ out[7]);

always_comb
begin
	a = alu_in_a;
	b = alu_in_b;
	cin = ~alu_cinclr & alu_cin;
	out = 8'b0;
	cout = cin;
	case (alu_func)
	ALUTXA:	out = a;
	ALUTXB:	out = b;
	ALUADD:	{cout, out} = a + b + {7'b0, cin};
	ALUSUB:	begin
		b = ~b;
		{cout, out} = a + b + {7'b0, ~cin};
		cout = ~cout;
	end
	ALUAND:	out = a & b;
	ALUORA:	out = a | b;
	ALUEOR:	out = a ^ b;
	ALUROL:	{cout, out} = {a, cout};
	ALUROR:	{out, cout} = {cout, a};
	ALUBIT:	out = a & b;
	endcase
	alu_out = out;
	alu_cout = cout;
end

endmodule
