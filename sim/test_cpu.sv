`timescale 1 ns / 1 ns

module test_cpu;

logic clk, qclk[3], n_reset, n_reset_async;
logic [15:0] addr;
wire [7:0] data;
logic rw;
cpu c0 (.dclk(qclk[1]), .*);

logic clk4;
initial
begin
	clk4 = 1'b0;
	forever #1ns clk4 = ~clk4;
end

logic clkd;
always_ff @(posedge clk4, negedge n_reset)
	if (~n_reset)
		clkd <= 0;
	else
		clkd <= ~clkd;

always_ff @(posedge clkd, negedge n_reset)
	if (~n_reset)
		clk <= 0;
	else
		clk <= ~clk;

logic dclk;
always_ff @(posedge clk4)
	{qclk[2], qclk[1], qclk[0]} <= {qclk[1], qclk[0], clk};

initial
begin
	n_reset_async = 1'b0;
	#2ns n_reset_async = 1'b1;
end

always_ff @(posedge clk4, negedge n_reset_async)
	if (~n_reset_async)
		n_reset <= 1'b0;
	else
		n_reset <= n_reset_async;

logic [7:0] ram[22] = '{
	'ha2, 'hbc,		// LDX #i
	'ha4, 'h00,		// LDY d
	'ha5, 'h03,		// LDA d
	'ha6, 'h05,		// LDX d
	'ha2, 'h03,		// LDX #i
	'hbd, 'h00, 'h01,	// LDA a, x
	'hb5, 'h02,		// LDA d, x
	'had, 'h12, 'h34,	// LDA a
	'ha9, 'h12,		// LDA #i
	'ha2, 'h23		// LDX #i
};

logic [7:0] ram_out;
assign data = rw ? ram_out : 8'bz;

always_ff @(posedge qclk[0])
begin
	ram_out <= ram[addr];
	if (~rw)
		ram[addr] <= ram_out;
end

endmodule
