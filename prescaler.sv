module prescaler #(parameter n) (
	input logic n_reset, clk,
	output logic out,
	output logic [n - 1 : 0] counter
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		counter <= 'b0;
		out <= 'b0;
	end else if (counter == 'b0) begin
		counter <= {n{1'b1}};
		out <= 'b1;
	end else begin
		counter <= counter - 1'b1;
		out <= 'b0;
	end

endmodule
