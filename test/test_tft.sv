`timescale 1 us / 1 ns

module test_tft;

logic n_reset, clk, nclk;
assign nclk = ~clk;

// TFT
logic en;
assign en = 1'b1;
logic disp, de, dclk, vsync, hsync;
logic [8:0] x, y;
logic [23:0] data, out;
tft #(.HN($clog2(480 - 1)), .VN($clog2(272 - 1)),
	.HT('{40, 1, 479, 1}), .VT('{10, 1, 271, 1})) tft0 (.pixclk(clk), .*);

// TFT pixel data
always_ff @(negedge clk, negedge n_reset)
	if (~n_reset)
		data <= 24'h0;
	else if (x == 9'd0)
		data <= 24'hff0000;
	else if (x == 9'd479)
		data <= 24'h00ff00;
	else if (y == 9'd0)
		data <= 24'h0000ff;
	else if (y == 9'd271)
		data <= 24'hffff00;
	else
		data <= {x[7:0], y[7:0], 8'h0};

initial
begin
	n_reset = 1'b0;
	#750ns n_reset = 1'b1;
end

initial
begin
	clk = 1'b1;
	forever #500ns clk = ~clk;
end

endmodule
