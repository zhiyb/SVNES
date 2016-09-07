`timescale 1 ps / 1 ps

module test_arbiter;

logic n_reset, clk, nclk;
assign nclk = ~clk;

sys_if sys(.*);

logic req[8], sel[8];

arbiter #(.N(8)) a0 (.*);

initial
begin
	for (int i = 0; i != 8; i++)
		req[i] = 1'b0;
	req[3] = 1'b1;
	req[5] = 1'b1;
	#4us req[2] = 1'b1;
	req[3] = 1'b0;
	req[0] = 1'b1;
	req[7] = 1'b1;
end

initial
begin
	n_reset = 1'b0;
	#1us n_reset = 1'b1;
end

initial
begin
	clk = 1'b0;
	forever #500ns clk = ~clk;
end

endmodule
