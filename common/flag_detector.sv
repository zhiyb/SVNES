module flag_detector (
	input logic clk, n_reset,
	input logic flag,
	output logic out
);

logic flag_delayed;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		flag_delayed <= 1'b0;
	else
		flag_delayed <= flag;

assign out = flag & ~flag_delayed;

endmodule
