module counter #(parameter n = 3) (
	input logic n_reset, clk,
	output logic out,
	input logic [n - 1:0] top,
	output logic [n - 1:0] counter
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		counter <= {n{1'b0}};
		out <= 1'b0;
	end else begin
		if (counter == top) begin
			counter <= {n{1'b0}};
			out <= 1'b0;
		end else begin
			counter <= counter + {{n - 1{1'b0}}, 1'b1};
			if (counter == (top >> 1))
				out <= 1'b1;
		end
	end

endmodule
