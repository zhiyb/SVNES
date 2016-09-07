module apu_timer #(parameter N) (
	input logic clk, n_reset,
	output logic clkout,
	input logic reload, loop,
	input logic [N - 1:0] load,
	output logic [N - 1:0] cnt
);

logic tick;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		tick <= 1'b0;
	else
		tick <= cnt == {N{1'b0}};

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		cnt <= {N{1'b0}};
	else if (reload)
		cnt <= load;
	else if (cnt == {N{1'b0}}) begin
		if (loop)
			cnt <= load;
	end else
		cnt <= cnt - {{N - 1{1'b0}}, 1'b1};

assign clkout = tick & ~clk;

endmodule
