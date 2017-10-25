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

logic [7:0] ram[72] = '{
	'h38,			// SEC
	'h90, 'hfe,		// BCC
	'h18,			// CLC
	'hb0, 'hfe,		// BCS
	'h90, 'h01,		// BCC
	'h18,			// CLC
	'h38,			// SEC
	'hb0, 'hf5,		// BCS
	'ha9, 'h34,		// LDA #i
	'h00,			// BRK
	'h08,			// PHP
	'h48,			// PHA
	'ha9, 'h12,		// LDA #i
	'h28,			// PLP
	'ha2, 'h03,		// LDX #i
	'h2c, 'h04, 'h00,	// BIT a
	'h06, 'h02,		// ASL d
	'h85, 'h04,		// STA d
	'ha0, 'hee,		// LDY #i
	'ha0, 'h04,		// LDY #i
	'h95, 'h01,		// STA d, x
	'h61, 'h01,		// ADC (d, x)
	'h09, 'h46,		// ORA #i
	'he9, 'h12,		// SBC #i
	'h69, 'h12,		// ADC #i
	'ha9, 'h34,		// LDA #i
	'h58,			// CLI
	'h99, 'h34, 'h12,	// STA a, y
	'h99, 'hde, 'hbc,	// STA a, y
	'h9d, 'hde, 'hbc,	// STA a, x
	'h8c, 'h56, 'h34,	// STY a
	'h8e, 'h9a, 'h78,	// STX a
	'h8d, 'hde, 'hbc,	// STA a
	'h94, 'h01,		// STY d, x
	'h86, 'h06,		// STX d
	'hb1, 'h0d,		// LDA (d), y
	'ha1, 'h04		// LDA (d, x)
};

logic [7:0] ram_out;
assign data = rw ? ram_out : 8'bz;

always_ff @(posedge qclk[0])
begin
	ram_out <= ram[addr];
	if (addr == 16'hfffe)
		ram_out <= 8'h01;
	else if (addr == 16'hffff)
		ram_out <= 8'h00;
	if (~rw)
		ram[addr] <= data;
end

endmodule
