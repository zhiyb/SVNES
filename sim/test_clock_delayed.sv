module test_clock_delayed;

logic clk, clkRef, n_reset;
logic delay;
logic clkout;

clock_delayed #(2, 4) c0 (clk, clkRef, n_reset, delay, clkout);

initial
begin
	clk = 1'b0;
	forever #5ns clk = ~clk;
end

initial
begin
	#2ns clkRef = 1'b0;
	forever #70ns clkRef = ~clkRef;
end

initial
begin
	delay = 1'b0;
	n_reset = 1'b0;
	#8ns n_reset = 1'b1;
	#140ns delay = 1'b1;
	#340ns delay = 1'b0;
end

endmodule
