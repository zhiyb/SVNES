module prescaler #(parameter n) (
	input logic n_reset, clk,
	output logic out,
	output logic [n : 0] counter
);

assign counter[0] = clk;

genvar i;
generate
for (i = 0; i != n; i++) begin: gen_dff
	always_ff @(posedge counter[i], negedge n_reset)
		if (~n_reset)
			counter[i + 1] <= 1'b0;
		else
			counter[i + 1] <= ~counter[i + 1];
end
endgenerate

endmodule
