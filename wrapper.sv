module wrapper (
	input logic CLOCK_50,
	input logic [1:0] KEY,
	input logic [3:0] SW,
	output logic [7:0] LED,
	
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ,
	
	inout logic I2C_SCLK, I2C_SDAT,
	
	output logic G_SENSOR_CS_N,
	input logic G_SENSOR_INT,
	
	output logic ADC_CS_N, ADC_SADDR, ADC_SCLK,
	input logic ADC_SDAT,
	
	inout logic [33:0] GPIO_0,
	input logic [1:0] GPIO_0_IN,
	inout logic [33:0] GPIO_1,
	input logic [1:0] GPIO_1_IN/*,
	inout logic [12:0] GPIO_2,
	input logic [2:0] GPIO_2_IN*/
);

logic n_reset, fetch, dbg;
assign n_reset = KEY[1];

// Clocks
logic clk50M, clkAudio, clkTFT, clkSDRAM, clkTap;
assign clk50M = CLOCK_50;
// 10MHz; 20MHz; 23.89MHz; 95.6MHz; 215MHz
pll pll0 (.areset(1'b0), .inclk0(clk50M), .locked(),
	.c0(clkAudio), .c1(), .c2(clkTFT), .c3(clkSDRAM), .c4(clkTap));

`define NTSC	0
`define PAL		1
`define DENDY	2

logic clk_Master[3], clk_PPU[3], clk_CPU[3];
//assign clk_Master[`DENDY] = clk_Master[`PAL];
//assign clk_PPU[`DENDY] = clk_PPU[`PAL];
pll_ntsc pll1 (.areset(1'b0), .inclk0(clk50M), .locked(),
	.c0(clk_Master[`NTSC]), .c1(clk_PPU[`NTSC]), .c2(clk_CPU[`NTSC]));
//pll_pal pll2 (.areset(1'b0), .inclk0(clk50M), .c0(clk_PPU[`PAL]), .c1(clk_CPU[`DENDY]));

parameter clksel = `NTSC;

logic clkMaster, clkPPU, clkCPU;
assign clkMaster = clk_Master[clksel];
assign clkPPU = clk_PPU[clksel];
assign clkCPU = clk_CPU[clksel];

// GPIO
wire [7:0] io[2];
logic [7:0] iodir[2], ioin;
assign ioin = {GPIO_1_IN, GPIO_0_IN, SW};

genvar i;
generate
	for (i = 0; i != 8; i++) begin: gen_io0
		assign io[0][i] = iodir[0][i] ? 1'bz : ioin[i];
	end
endgenerate

// SPI
logic cs, miso;
logic mosi, sck;
assign cs = 1'b1, miso = 1'b1;

// Audio PWM
logic [7:0] audio;
logic aout;
assign GPIO_1[25] = SW[1] & aout;
apu_pwm #(.N(8)) pwm0 (.clk(clkAudio), .cmp(audio), .q(aout), .en(1'b1), .*);

// TFT
parameter width = 800, height = 480;

logic [23:0] tft_out;
assign GPIO_0[23:0] = tft_out;
logic [9:0] tft_x, tft_y;
logic tft_hblank, tft_vblank;
tft #(.HN(10), .VN(10),
	//.HT('{1, 40, 479, 1}), .VT('{1, 9, 271, 1})) tft0 (
	.HT('{1, 43, 799, 15}), .VT('{1, 20, 479, 6})) tft0 (
	.n_reset(n_reset), .pixclk(clkTFT), .en(SW[0]),
	.hblank(tft_hblank), .vblank(tft_vblank), .x(tft_x), .y(tft_y),
	.disp(GPIO_0[24]), .de(GPIO_0[25]), .dclk(GPIO_0[28]),
	.vsync(GPIO_0[26]), .hsync(GPIO_0[27]));

// SDRAM
logic [23:0] addr_in;
logic [15:0] data_in;
logic we, req;
logic rdy;

logic [23:0] addr_out;
logic [15:0] data_out;
logic rdy_out;

//sdram #(.TINIT(11600), .TREFC(906)) sdram0 (.clk(clkSDRAM), .en(1'b1), .*);
//sdram #(.TINIT(9600), .TREFC(750), .TWAIT(8)) sdram0 (.clk(clkSDRAM), .en(1'b1), .*);
sdram #(.TINIT(9566), .TREFC(747), .TWAIT(8)) sdram0 (.clk(clkSDRAM), .en(1'b1), .*);

// SDRAM arbiter
parameter ARB0N = 2;
logic arb0_req[ARB0N], arb0_sel[ARB0N], arb0_rdy[ARB0N];
arbiter #(.N(ARB0N)) arb0 (.n_reset(n_reset), .clk(clkSDRAM),
	.ifrdy(rdy), .ifreq(req), .ifswap(1'b0),
	.req(arb0_req), .sel(arb0_sel), .rdy(arb0_rdy));

logic [23:0] arb0_addr[ARB0N];
assign addr_in = arb0_addr[arb0_sel[1]];
logic [15:0] arb0_data[ARB0N];
assign data_in = arb0_data[1];
logic arb0_we[ARB0N];
assign we = arb0_we[arb0_sel[1]];

// TFT pixel data fetch (SDRAM arbiter interface 0)
logic tft_rdy, tft_underrun;
assign tft_rdy = rdy_out && addr_out[23:20] == 4'hf;
tft_fetch tft_fetch0 (.clk(clkSDRAM), .out(tft_out),
	.vblank(tft_vblank), .hblank(tft_hblank), .underrun(tft_underrun),
	.req(arb0_req[0]), .rdy(arb0_rdy[0]), .ifrdy(tft_rdy), .addr(arb0_addr[0]), .data(data_out), .*);

assign arb0_data[0] = 16'h0;
assign arb0_we[0] = 1'b0;

// TFT pixel data output buffer (SDRAM arbiter interface 1)
logic tft_we, tft_overrun;
logic [23:0] tft_addr;
logic [15:0] tft_data;
tft_write tft_write0 (.clk(clkSDRAM), .clkData(clkPPU),
	.we(tft_we), .addr_in(tft_addr), .data_in(tft_data), .overrun(tft_overrun),
	.req(arb0_req[1]), .rdy(arb0_rdy[1]), .addr(arb0_addr[1]), .data(arb0_data[1]), .*);

assign arb0_we[1] = 1'b1;

// PPU pixel output
logic ppu_we;
logic [9:0] ppu_x, ppu_y;
logic [19:0] ppu_addr;
assign ppu_addr = width * ppu_y + ppu_x;
logic [23:0] ppu_rgb;
logic [15:0] ppu_data;
assign ppu_data = {ppu_rgb[23:19], ppu_rgb[15:10], ppu_rgb[7:3]};

assign tft_we = ppu_we & SW[2];
assign tft_addr = {4'hf, ppu_addr};
assign tft_data = ppu_data;
/*
// SDRAM cache
logic cache_we, cache_req;
logic cache_miss, cache_rdy, cache_swap;
logic [23:0] cache_addr;
logic [15:0] cache_data_in, cache_data_out;
cache cache0 (.n_reset(n_reset), .clk(clkSDRAM),
	.we(cache_we), .req(cache_req), .miss(cache_miss), .rdy(cache_rdy), .swap(cache_swap),
	.addr(cache_addr), .data_in(cache_data_in), .data_out(cache_data_out),
	.if_addr_out(addr_in), .if_data_out(data_in),
	.if_we(we), .if_req(req), .if_rdy(rdy),
	.if_addr_in(addr_out), .if_data_in(data_out), .if_rdy_in(rdy_out)
);

// SDRAM cache arbiter
parameter ARBN = 2;
logic arb_req[ARBN], arb_sel[ARBN], arb_rdy[ARBN], arb_we[ARBN];
logic [23:0] arb_addr[ARBN];
arbiter #(.N(ARBN)) arb0 (.n_reset(n_reset), .clk(clkSDRAM),
	.ifrdy(cache_rdy), .ifreq(cache_req), .ifswap(cache_swap),
	.req(arb_req), .sel(arb_sel), .rdy(arb_rdy));

assign cache_addr = arb_addr[arb_sel[1]];
assign cache_we = arb_we[arb_sel[1]];
*/
// System
system sys0 (.n_reset_in(n_reset), .*);

// Debug LEDs
logic latch_underrun;
flag_keeper flag0 (.n_reset(n_reset), .clk(clkSDRAM), .clk_s(clkSDRAM),
	.flag(tft_underrun), .clr(~KEY[0]), .out(latch_underrun));

logic latch_overrun;
flag_keeper flag1 (.n_reset(n_reset), .clk(clkSDRAM), .clk_s(clkSDRAM),
	.flag(tft_overrun), .clr(~KEY[0]), .out(latch_overrun));

assign LED[7:0] = {/*cache_req & cache_miss, req, rdy*/3'h0, aout,
	tft_vblank, tft_hblank, latch_overrun, latch_underrun};

endmodule
