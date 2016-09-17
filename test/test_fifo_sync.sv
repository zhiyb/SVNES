`timescale 1 us / 1 ns

module test_fifo_sync;

logic clk, n_reset;
logic wrreq, rdack;
logic empty, full, underrun, overrun;
logic [15:0] in, out;

fifo_sync #(.N(16), .DEPTH_N(2)) fifo0 (.*);

initial
begin
	wrreq = 1'b0;
	forever begin
		#2us wrreq = 1'b1;
		#1us wrreq = 1'b0;
	end
end

initial
begin
	rdack = 1'b0;
	for (int i = 0; i < 10; i++) begin
		#4us rdack = 1'b1;
		#1us rdack = 1'b0;
	end
	forever begin
		#1us rdack = 1'b1;
		#1us rdack = 1'b0;
	end
end

initial
begin
	in = 16'h0;
	forever #1us in++;
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
