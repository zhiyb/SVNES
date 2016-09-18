module arbiter #(parameter N, DEF = 0) (
	input logic n_reset, clk,
	input logic ifrdy,
	output logic ifreq,
	input logic req[N],
	output logic sel[N], rdy[N]
);

logic dis[N + 1], ifreqs[N + 1];
assign dis[0] = dis[N];
assign ifreqs[0] = 1'b0;
assign ifreq = ifreqs[N];

genvar i;
generate
for (i = 0; i != N; i++) begin: gen
	logic out, next;
	assign out = ~sel[i] & ~dis[i] & req[i];
	assign next = (sel[i] & ~dis[i]) | out;
	assign dis[i + 1] = (~sel[i] & dis[i]) | out;
	assign rdy[i] = sel[i] & ifrdy;
	assign ifreqs[i + 1] = ifreqs[i] | (sel[i] & req[i]);
	
	always_ff @(posedge clk, negedge n_reset)
		if (~n_reset)
			sel[i] <= i == DEF;
		else if (ifrdy)
			sel[i] <= next;
end
endgenerate

endmodule
