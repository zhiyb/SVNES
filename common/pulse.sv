module pulse (
	input logic clk, n_reset, d,
	output logic q
);

logic p;
assign q = d & ~p;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		p <= 1'b0;
	else
		p <= d;

endmodule
