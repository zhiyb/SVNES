module prescaler #(parameter n) (
	input logic n_reset, clk,
	output logic out,
	output logic [n : 0] counter
);

assign counter[0] = clk;

genvar i;
generate
for (i = 0; i != n; i++) begin: gen_dff
	dff d0 (.clk(counter[i]), .n_reset(n_reset), .d(~counter[i + 1]), .q(counter[i + 1]));
end
endgenerate

endmodule
