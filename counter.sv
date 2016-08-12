module counter #(parameter bits = 3) (
	input logic n_reset, clk, in, output logic out,
	input logic [bits - 1:0] top,
	output logic [bits - 1:0] counter
);

always_ff @(posedge in, negedge n_reset)
	if (~n_reset)
	begin
		counter <= 'b0;
		out <= 'b0;
	end
	else
	begin
		if (counter == top)
		begin
			out <= 'b1;
			counter <= 'b0;
		end
		else
		begin
			out <= 'b0;
			counter <= counter + 1'b1;
		end
	end

endmodule
