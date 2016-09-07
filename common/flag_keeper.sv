module flag_keeper (
	input logic clk, clk_s, n_reset,
	input logic flag, clr,
	output logic out
);

logic out_clr;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		out <= 1'b0;
	else if (flag)
		out <= 1'b1;
	else if (out_clr)
		out <= 1'b0;

always_ff @(posedge clk_s, negedge n_reset)
	if (~n_reset)
		out_clr <= 1'b0;
	else
		out_clr <= out & clr;

endmodule
