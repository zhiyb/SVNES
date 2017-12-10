`timescale 1 ps / 1 ps

module test_system;

logic clkCPU2, clkPPU, n_reset;
// Audio
logic [7:0] audio;
// Video
logic [23:0] video_rgb;
logic video_vblank, video_hblank;

system sys0 (.*);

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
