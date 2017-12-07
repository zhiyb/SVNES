// {{{ Clocks and reset control
module clk_reset (
	input logic CLOCK_50,
	output logic clkSYS, clkSDRAM, clkTFT, clkAudio,
	output logic clkMaster, clkPPU, clkCPU2,
	input logic KEY,
	output logic [1:0] clk,
	input logic n_reset_mem,
	output logic n_reset, n_reset_ext
);

// Reset control
always_ff @(posedge CLOCK_50)
begin
	n_reset_ext <= KEY;
	n_reset <= n_reset_ext & n_reset_mem;
end

// Clocks
logic clk10M, clk50M, clkSYS1, clkSYS2;
assign clk50M = CLOCK_50;
assign clkAudio = clk10M;
pll pll0 (.inclk0(clk50M), .locked(),
	.c0(clk10M), .c1(clkTFT), .c2(clkSDRAM), .c3(clkSYS1), .c4(clkSYS2));

// System interface clock switch for debugging
`ifdef MODEL_TECH
assign clk = 0;
assign clkSYS = clkSYS1;
`else
logic [23:0] cnt;
always_ff @(posedge clk10M)
	if (cnt == 0) begin
		cnt <= 10000000;
		clk <= KEY ? clk : clk + 1;
	end else
		cnt <= cnt - 1;

logic sys[4];
assign sys[0] = clkSYS1;
assign sys[1] = clkSDRAM;
assign sys[2] = clkSYS1;
assign sys[3] = clkSYS2;
assign clkSYS = sys[clk];
`endif

// NES clocks
pll_ntsc pll1 (.areset(1'b0), .inclk0(clk50M), .locked(),
	.c0(clkMaster), .c1(clkPPU), .c2(clkCPU2));

endmodule
// }}}

module wrapper (
	// {{{ Inputs & outputs
	input logic CLOCK_50,
	input logic [1:0] KEY,
	input logic [3:0] SW,
	output logic [7:0] LED,
	
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ,
	
	inout wire I2C_SCLK, I2C_SDAT,
	
	output logic G_SENSOR_CS_N,
	input logic G_SENSOR_INT,
	
	output logic ADC_CS_N, ADC_SADDR, ADC_SCLK,
	input logic ADC_SDAT,
	
	inout wire [33:0] GPIO_0,
	input logic [1:0] GPIO_0_IN,
	inout wire [33:0] GPIO_1,
	input logic [1:0] GPIO_1_IN,
	inout wire [12:0] GPIO_2,
	input logic [2:0] GPIO_2_IN
	// }}}
);

// Clocks and reset control
logic clkSYS, clkSDRAM, clkTFT, clkAudio;
logic clkMaster, clkPPU, clkCPU2;
logic [1:0] clk;
logic n_reset, n_reset_ext, n_reset_mem;
clk_reset cr0 (.KEY(KEY[1]), .*);

// Memory subsystem with arbiter
localparam AN = 24, DN = 16, IN = 4, BURST = 8;

logic [AN - 1:0] arb_addr[IN];
logic [DN - 1:0] arb_data[IN];
logic arb_wr[IN];
logic [IN - 1:0] arb_req, arb_ack;

logic [DN - 1:0] arb_data_out;
logic [IN - 1:0] arb_valid;

logic [1:0] sdram_level;
logic sdram_empty, sdram_full;
sdram_shared #(AN, DN, IN, BURST) mem0 (.n_reset(n_reset_ext), .*);

// Memory access arbiter assignments
localparam tft = 0, ppu = 1, rect = 2, test = 3;

// TFT
localparam TFT_BASE = 24'hfa0000, TFT_LS = 480;
logic [5:0] tft_level;
logic tft_empty, tft_full;
`ifdef MODEL_TECH
tft #(AN, DN, BURST, TFT_BASE, 10, '{1, 1, 256, 1}, 10, '{1, 1, 128, 1}) tft0
`else
tft #(AN, DN, BURST, TFT_BASE, 10, '{1, 40, 479, 1}, 10, '{1, 9, 271, 1}) tft0
//tft #(AN, DN, BURST, 24'hfa0000, 10, '{1, 43, 799, 15}, 10, '{1, 20, 479, 6}) tft0
`endif
	(.clkSYS(clkSYS), .clkTFT(clkTFT), .n_reset(n_reset),
	.mem_data(arb_data_out), .mem_valid(arb_valid[tft]),
	.req_addr(arb_addr[tft]), .req_ack(arb_ack[tft]), .req(arb_req[tft]),
	.disp(GPIO_0[26]), .de(GPIO_0[29]), .dclk(GPIO_0[25]),
	.vsync(GPIO_0[28]), .hsync(GPIO_0[27]),
	.out({GPIO_0[7:0], GPIO_0[15:8], GPIO_0[23:16]}),
	.level(tft_level), .empty(tft_empty), .full(tft_full));
assign arb_wr[tft] = 1'b0;
assign arb_data[tft] = 'bx;

logic tft_pwm;
assign GPIO_0[24] = tft_pwm;
assign tft_pwm = n_reset;

// Rectangular background fill
localparam PPU_X = 64, PPU_Y = 20, PPU_W = 256, PPU_H = 240, MARGIN = 4;
logic rect_active;
rectfill #(AN, DN, TFT_BASE, 16'h0841, 9, 9, TFT_LS,
	// x-offset, y-offset, x-length, y-length
	PPU_X - MARGIN, PPU_Y - MARGIN, PPU_W + MARGIN * 2, PPU_H + MARGIN * 2)
	rect0 (clkSYS, n_reset, arb_addr[rect], arb_data[rect],
	arb_req[rect], arb_wr[rect], arb_ack[rect],
	~KEY[0], rect_active);

// Memory RW test client
logic test_fail;
`ifdef MODEL_TECH
mem_test #(BURST, TFT_BASE + 24'h010000, 24'h000010) test0 (clkSYS, n_reset,
	arb_data_out, arb_valid[test], arb_addr[test], arb_data[test],
	arb_req[test], arb_wr[test], arb_ack[test],
	test_fail, SW[2], ~KEY[1], SW[3]);
`else
mem_test #(BURST, TFT_BASE + 24'h000100, 24'h001000) test0 (clkSYS, n_reset,
	arb_data_out, arb_valid[test], arb_addr[test], arb_data[test],
	arb_req[test], arb_wr[test], arb_ack[test],
	test_fail, SW[2], ~KEY[1], SW[3]);
`endif

// Audio PWM
logic [7:0] audio;
logic aout;
assign GPIO_1[25] = SW[0] | aout;
apu_pwm #(.N(8)) pwm0 (clkAudio, n_reset, audio, 1'b1, aout);

// Video frame buffer
logic [23:0] video_rgb;
logic video_vblank, video_hblank, fb_empty, fb_full;
ppu_fb #(AN, DN, TFT_BASE, 9, 9,
	PPU_X, PPU_Y, TFT_LS) fb0 (clkSYS, clkPPU, n_reset,
	arb_addr[ppu], arb_data[ppu], arb_req[ppu], arb_wr[ppu], arb_ack[ppu],
	video_rgb, video_vblank, video_hblank, fb_empty, fb_full);

// System
system sys0 (.*);

// Debugging LEDs
assign LED[7:0] = {clk, test_fail, fb_full, fb_empty, tft_empty, sdram_full, sdram_empty};

endmodule
