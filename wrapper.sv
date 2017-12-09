// {{{ Clocks and reset control
module clk_reset (
	input logic CLOCK_50,
	output logic clkSYS, clkSDRAMIO, clkSDRAM, clkTFT, clkAudio,
	output logic clkMaster, clkPPU, clkCPU2,
	input logic [1:0] KEY,
	input logic [3:0] SW,
	output logic clk,
	input logic n_reset_mem,
	output logic n_reset, n_reset_ext
);

// Reset control
always_ff @(posedge clkSYS)
begin
	n_reset_ext <= KEY[1];
	n_reset <= n_reset_ext & n_reset_mem;
end

// Clocks
logic clk10M, clk50M, clkSYS1;
assign clk50M = CLOCK_50;
assign clkAudio = clk10M;
pll pll0 (.inclk0(clk50M), .locked(),
	.c0(clkSDRAMIO), .c1(clkSDRAM), .c2(clk10M), .c3(clkTFT), .c4(clkSYS1));

// System interface clock switch for debugging
`ifdef MODEL_TECH
assign clk = 0;
assign clkSYS = clkSYS1;
`else
logic [23:0] cnt;
always_ff @(posedge clk10M)
	if (cnt == 0) begin
		cnt <= 10000000;
		if (~KEY[1])
			clk <= ~clk;
	end else
		cnt <= cnt - 1;

logic sys[2];
assign sys[0] = clkSYS1;
assign sys[1] = clkSDRAM;
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
logic clkSYS, clkSDRAMIO, clkSDRAM, clkTFT, clkAudio;
logic clkMaster, clkPPU, clkCPU2;
logic clk;
logic n_reset, n_reset_ext, n_reset_mem;
clk_reset cr0 (.*);

// NES system
logic [7:0] audio;
logic [23:0] video_rgb;
logic video_vblank, video_hblank;
system sys0 (.*);

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
localparam tft = 0, disp = 3;

assign arb_addr[1] = 'bx;
assign arb_data[1] = 'bx;
assign arb_wr[1] = 'bx;
assign arb_req[1] = 0;

assign arb_addr[2] = 'bx;
assign arb_data[2] = 'bx;
assign arb_wr[2] = 'bx;
assign arb_req[2] = 1'b0;

// TFT frame buffer
localparam TFT_BASE = 24'hfa0000, TFT_LS = 800;
logic [5:0] tft_level;
logic tft_empty, tft_full;
`ifdef MODEL_TECH
tft #(AN, DN, BURST, TFT_BASE, 10, '{1, 1, 256, 1}, 10, '{1, 1, 128, 1}) tft0
`else
//tft #(AN, DN, BURST, TFT_BASE, 10, '{1, 40, 479, 1}, 10, '{1, 9, 271, 1}) tft0
tft #(AN, DN, BURST, TFT_BASE, 10, '{1, 43, 799, 15}, 10, '{1, 20, 479, 6}) tft0
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

// Display elements
logic fb_empty, fb_full, test_fail;
display #(AN, DN, BURST, TFT_BASE, TFT_LS) disp0 (clkSYS, clkPPU, n_reset,
	// Memory interface
	arb_addr[disp], arb_data[disp],
	arb_req[disp], arb_wr[disp], arb_ack[disp],
	arb_data_out, arb_valid[disp],
	// PPU video
	video_rgb, video_vblank, video_hblank,
	// Switches
	KEY, SW,
	// Status
	fb_empty, fb_full, test_fail
);

// Audio PWM
logic aout;
assign GPIO_1[25] = aout;
apu_pwm #(.N(8)) pwm0 (clkAudio, n_reset, audio, SW[0], aout);

// Debugging LEDs
assign LED[7:0] = {clk, test_fail, fb_full, fb_empty,
	tft_full, tft_empty, sdram_full, sdram_empty};

endmodule
