module dff (
	input logic clk, n_reset, d,
	output logic q
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		q <= 1'b0;
	else
		q <= d;

endmodule
