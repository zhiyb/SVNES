module lfsr #(parameter N, RESET) (
	input logic clk, n_reset,
	input logic fb,
	output logic [N - 1:0] data
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		data <= RESET;
	else
		data <= {fb, data[N - 1:1]};

endmodule
