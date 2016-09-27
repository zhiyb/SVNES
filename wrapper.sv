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

logic n_reset_in, n_reset, fetch, dbg;
assign n_reset_in = KEY[1];

// Clocks

logic clk50M, clkTFT, clkSDRAM, clkSYS;
assign clk50M = CLOCK_50;
// 10MHz; 20MHz; 33.125MHz; 265MHz
pll pll0 (.areset(1'b0), .inclk0(clk50M), .locked(),
	.c0(), .c1(), .c2(clkTFT), .c3(clkSYS));

`define NTSC	0
`define PAL		1
`define DENDY	2

logic clkMaster[3], clkPPU[3], clkCPU[3];
//assign clkMaster[`DENDY] = clkMaster[`PAL];
//assign clkPPU[`DENDY] = clkPPU[`PAL];
pll_ntsc pll1 (.areset(~n_reset_in), .inclk0(clk50M), .locked(),
	.c0(clkMaster[`NTSC]), .c1(clkPPU[`NTSC]), .c2(clkCPU[`NTSC]));
//pll_pal pll2 (.areset(~n_reset_in), .inclk0(clk50M), .c0(clkPPU[`PAL]), .c1(clkCPU[`DENDY]));

parameter clksel = `NTSC;

logic clk_Master, clk_PPU, clk_CPU;
assign clk_Master = clkMaster[clksel];
assign clk_PPU = clkPPU[clksel];
assign clk_CPU = clkCPU[clksel];
/*
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
assign GPIO_0[25] = aout;
apu_pwm #(.N(8)) pwm0 (.n_reset(n_reset_in), .clk(clk10M), .cmp(audio), .q(aout), .en(1'b1), .*);
*/
// TFT
assign data_in = 16'h1234;
logic [23:0] tft_out;
assign GPIO_0[23:0] = tft_out;
logic [9:0] tft_x, tft_y;
logic tft_hblank, tft_vblank;
tft #(.HN($clog2(480 - 1)), .VN($clog2(272 - 1)),
	.HT('{1, 40, 479, 1}), .VT('{1, 9, 271, 1})) tft0 (
	//.HT('{1, 43, 799, 209}), .VT('{1, 20, 479, 21})) tft0 (
	.n_reset(n_reset_in), .pixclk(clkTFT), .en(SW[0]),
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

sdram #(.TINIT(9600), .TREFC(750)) sdram0 (.n_reset(n_reset_in), .clk(clkSYS), .en(1'b1), .*);

// SDRAM arbiter
parameter ARB0N = 2;
logic arb0_req[ARB0N], arb0_sel[ARB0N], arb0_rdy[ARB0N];
arbiter #(.N(ARB0N)) arb0 (.n_reset(n_reset_in), .clk(clkSYS),
	.ifrdy(rdy), .ifreq(req), .ifswap(1'b0),
	.req(arb0_req), .sel(arb0_sel), .rdy(arb0_rdy));

logic [23:0] arb0_addr[ARB0N];
assign addr_in = arb0_addr[arb0_sel[1]];
assign data_in = 16'h1234;
logic arb0_we[ARB0N];
assign we = arb0_we[arb0_sel[1]];

// TFT pixel data fetch (SDRAM arbiter interface 0)
logic tft_req, tft_rdy, tft_underrun;
assign tft_rdy = rdy_out && addr_out[23:20] == 4'hf;
logic [23:0] tft_addr;
//assign tft_data = {{5{tft_addr[0]}}, {6{tft_addr[1]}}, tft_addr[17:13]};
tft_fetch tft_fetch0 (.n_reset(n_reset_in), .out(tft_out),
	.vblank(tft_vblank), .hblank(tft_hblank), .underrun(tft_underrun),
	.req(tft_req), .ifrdy(tft_rdy), .addr(tft_addr), .data(data_out), .*);

assign arb0_req[0] = tft_req;
assign arb0_addr[0] = tft_addr;
assign arb0_we[0] = 1'b0;

// SDRAM arbiter interface 1
assign arb0_req[1] = 1'b0;
assign arb0_addr[1] = 24'h0;
assign arb0_we[1] = 1'b0;
/*
// SDRAM cache
logic cache_we, cache_req;
logic cache_miss, cache_rdy, cache_swap;
logic [23:0] cache_addr;
logic [15:0] cache_data_in, cache_data_out;
cache cache0 (.n_reset(n_reset_in), .clk(clkSDRAM),
	.we(cache_we), .req(cache_req), .miss(cache_miss), .rdy(cache_rdy), .swap(cache_swap),
	.addr(cache_addr), .data_in(cache_data_in), .data_out(cache_data_out),
	.if_addr_out(addr_in), .if_data_out(data_in),
	.if_we(we), .if_req(req), .if_rdy(rdy),
	.if_addr_in(addr_out), .if_data_in(data_out), .if_rdy_in(rdy_out)
);

// SDRAM arbiter
parameter ARBN = 2;
logic arb_req[ARBN], arb_sel[ARBN], arb_rdy[ARBN], arb_we[ARBN];
logic [23:0] arb_addr[ARBN];
arbiter #(.N(ARBN)) arb0 (.n_reset(n_reset_in), .clk(clkSDRAM),
	.ifrdy(cache_rdy), .ifreq(cache_req), .ifswap(cache_swap),
	.req(arb_req), .sel(arb_sel), .rdy(arb_rdy));

assign cache_addr = arb_addr[arb_sel[1]];
assign cache_we = arb_we[arb_sel[1]];

// System
logic ppu_clk_reg;
always_ff @(posedge clkSDRAM, negedge n_reset_in)
	if (~n_reset_in)
		ppu_clk_reg <= 1'b0;
	else
		ppu_clk_reg <= ~clk_PPU;

logic ppu_update;
flag_detector ppu_flag0 (.clk(clkSDRAM), .n_reset(n_reset_in), .flag(ppu_clk_reg), .out(ppu_update));

logic [23:0] ppu_addr, ppu_rgb;
assign arb_addr[1] = ppu_addr;
assign arb_we[1] = 1'b1;

logic ppu_req, ppu_rdy;
assign arb_req[1] = ppu_req;
assign ppu_rdy = arb_rdy[1];

always_ff @(posedge clkSDRAM, negedge n_reset_in)
	if (~n_reset_in)
		ppu_req <= 1'b0;
	else if (ppu_update)
		ppu_req <= 1'b1;
	else if (ppu_rdy)
		ppu_req <= 1'b0;

assign cache_data_in = {ppu_rgb[23:19], ppu_rgb[15:10], ppu_rgb[7:3]};

system sys0 (.*);
*/
// Debug LEDs
logic dbg_latch;
flag_keeper flag0 (.n_reset(n_reset_in), .clk(clkSYS), .clk_s(clkSYS),
	.flag(tft_underrun), .clr(~KEY[0]), .out(dbg_latch));

assign LED[7:0] = {/*cache_req & cache_miss, req, rdy*/4'h0, tft_vblank, tft_hblank, tft_req, dbg_latch};

endmodule
