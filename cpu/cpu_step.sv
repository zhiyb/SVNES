module cpu_step (
	input logic clk, n_reset,
	// CPU halting control
	input logic sync,
	output logic halt,
	// Step control inputs
	input logic step, step_en
);

logic [2:0] _step;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		_step <= 0;
	else
		_step <= {~_step[1] & _step[0], _step[0], step};

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		halt <= 1'b0;
	else if (step_en & sync)
		halt <= 1'b1;
	else if (_step[2])
		halt <= 1'b0;

endmodule
