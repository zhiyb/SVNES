`timescale 1 us / 1 ns

module test_system;

logic n_reset_in, fetch;
logic clkCPU, clkPPU;

logic irq, nmi;

// GPIO
wire [7:0] io[2];
logic [7:0] iodir[2];
// SPI
logic cs, miso;
logic mosi, sck;
// Audio
logic [7:0] audio;
// Graphics
logic [8:0] ppu_x, ppu_y;
logic [23:0] ppu_rgb;
logic ppu_we;

system sys0 (.*);

assign io[0] = io[1];

initial
begin
	nmi = 1'b1;
	//#30us nmi = 1'b0;
	#20us nmi = 1'b1;
end

initial
begin
	irq = 1'b1;
end

initial
begin
	n_reset_in = 1'b0;
	#1us n_reset_in = 1'b1;
end

initial
begin
	clkCPU = 1'b0;
	forever #500ns clkCPU = ~clkCPU;
end

initial
begin
	clkPPU = 1'b0;
	forever #125ns clkPPU = ~clkPPU;
end

endmodule
