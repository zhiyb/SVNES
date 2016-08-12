module pulse (
	input logic clk, n_reset, d,
	output logic q
);

logic p;
assign q = d & ~p;
dff d0 (.q(p), .*);

endmodule
