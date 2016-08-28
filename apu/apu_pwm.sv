module apu_pwm #(parameter N = 8) (
	input logic n_reset, clk,
	input logic [N - 1:0] cmp,
	input logic en,
	output logic q
);

logic [N - 1:0] cnt, compare;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		cnt <= {N{1'b0}};
		compare <= {N{1'b0}};
		q <= 1'b0;
	end else if (~en) begin
		cnt <= {N{1'b0}};
		q <= 1'b0;
	end else begin
		if (cnt == {N{1'b0}}) begin
			compare <= cmp;
			q <= 1'b0;
		end else if (cnt == compare)
			q <= 1'b1;
		cnt <= cnt - {{N - 1{1'b0}}, 1'b1};
	end

endmodule
