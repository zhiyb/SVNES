`timescale 1 ns / 1 ns

module test_cpu;

logic clk, qclk[3], n_reset, n_reset_async, nmi, irq;
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

initial
begin
	nmi = 1'b1;
	irq = 1'b1;
end

always_ff @(posedge clk4, negedge n_reset_async)
	if (~n_reset_async)
		n_reset <= 1'b0;
	else
		n_reset <= n_reset_async;

logic [7:0] ram[1024];

logic [7:0] vector[6] = '{
	'h12, 'h34,	// NMI (0xfffa)
	'h01, 'h00,	// RST (0xfffc)
	'h00, 'h00	// IRQ (0xfffe)
};

logic [7:0] rom[72] = '{
	'h40,			// RTI
	'h00,			// BRK
	'h20, 'h43, 'h21,	// JSR a
	'h60,			// RTS
	'h38,			// SEC
	'h38,			// SEC
	'h6c, 'h04, 'h00,	// JMP (a)
	'h4c, 'h12, 'h34,	// JMP a
	'h18,			// CLC
	'h90, 'hfe,		// BCC
	'h18,			// CLC
	'hb0, 'hfe,		// BCS
	'h38,			// SEC
	'hc6, 'h01,		// DEC d
	'hb0, 'hf5,		// BCS
	'ha9, 'h34,		// LDA #i
	'h48,			// PHA
	'ha9, 'h12,		// LDA #i
	'h28,			// PLP
	'ha2, 'h03,		// LDX #i
	'h2c, 'h04, 'h00,	// BIT a
	'h06, 'h02,		// ASL d
	'h85, 'h04,		// STA d
	'ha0, 'hee,		// LDY #i
	'h95, 'h01,		// STA d, x
	'h61, 'h01,		// ADC (d, x)
	'h09, 'h46,		// ORA #i
	'he9, 'h12,		// SBC #i
	'h69, 'h12,		// ADC #i
	'ha9, 'h34,		// LDA #i
	'h58,			// CLI
	'h99, 'hde, 'hbc,	// STA a, y
	'h8c, 'h56, 'h34,	// STY a
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
	if (addr >= 16'hfffa)
		ram_out <= vector[addr - 16'hfffa];
	else if (addr < $size(rom))
		ram_out <= rom[addr];
	else
		ram_out <= ram[addr];
	if (~rw) begin
		if (addr < $size(rom))
			rom[addr] <= data;
		else
			ram[addr] <= data;
	end
end

endmodule
