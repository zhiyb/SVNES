`timescale 1 ps / 1 ps

module test_system;

// Main system
logic clkCPU2, clkPPU, n_reset;
// External interface
logic clkCPU, clkCPUn, clkRAM;
logic sys_reset;
wire sys_irq;
// CPU bus
logic [15:0] sys_addr;
wire [7:0] sys_data;
logic sys_rw;
wire sys_rdy;
// PPU bus
logic [13:0] ppu_addr;
wire [7:0] ppu_data;
logic ppu_rd, ppu_wr;
// Audio
logic [7:0] audio;
// Video
logic [23:0] video_rgb;
logic video_vblank, video_hblank;

system sys0 (.*);

// Mappers
// Memory interface - CPU
logic [23:0] mem_addr;
logic [15:0] mem_data;
logic mem_req, mem_wr;
logic mem_ack;
logic [15:0] mem_out;
logic mem_valid;
assign mem_ack = 1'b0;
assign mem_out = 0;
assign mem_valid = 1'b0;
// Memory interface - PPU
logic [23:0] mem_ppu_addr;
logic [15:0] mem_ppu_data;
logic mem_ppu_req, mem_ppu_wr;
logic mem_ppu_ack;
logic [15:0] mem_ppu_out;
logic mem_ppu_valid;
assign mem_ppu_ack = 1'b0;
assign mem_ppu_out = 0;
assign mem_ppu_valid = 1'b0;
mapper map0 (.*);

initial
begin
	n_reset = 2'b00;
	#100ns n_reset = 2'b11;
end

// 2MHz clkCPU2
initial
begin
	clkCPU2 = 1'b0;
	forever #250ns clkCPU2 = ~clkCPU2;
end

// 5MHz clkPPU
initial
begin
	clkPPU = 1'b0;
	forever #100ns clkPPU = ~clkPPU;
end

endmodule
