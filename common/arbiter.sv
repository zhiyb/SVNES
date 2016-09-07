module arbiter #(parameter N, DEF = 0) (
	sys_if sys,
	input logic req[N],
	output logic sel[N]
);

logic dis[N + 1];
assign dis[0] = dis[N];

genvar i;

generate
for (i = 0; i != N; i++) begin: gen
	logic out, next;
	assign out = ~sel[i] & ~dis[i] & req[i];
	assign next = (sel[i] & ~dis[i]) | out;
	assign dis[i + 1] = (~sel[i] & dis[i]) | out;
	
	always_ff @(posedge sys.clk, negedge sys.n_reset)
		if (~sys.n_reset)
			sel[i] <= i == DEF;
		else
			sel[i] <= next;
end
endgenerate

endmodule
