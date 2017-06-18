module test_arbiter;

// N inputs, M outputs
localparam N = 4, M = 4;

logic [N - 1:0] request[M], grant[M];
logic [N - 1:0] rotate[M + 1], h[M + 1];
assign h[0] = {N{1'b1}};

genvar i;
generate
for (i = 0; i != M; i++) begin: gen
	assign rotate[i + 1] = {rotate[i][0], rotate[i][N - 1:1]};
	arbiter #(N) arb (request[i], grant[i], rotate[i], h[i], h[i + 1]);
end
endgenerate

initial
begin
	for (int out = 0; out != M; out++)
		for (int in = 0; in != N; in++)
			request[out][in] = in != out;
	rotate[0] = 'b1;
	forever #10ns rotate[0] = {rotate[0][N - 2:0], rotate[0][N - 1]};
end

endmodule
