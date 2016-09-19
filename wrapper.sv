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

logic clk1M, clk10M, clk20M, clk50M, clk140M;
assign clk50M = CLOCK_50;
logic pll0_locked;
pll pll0 (.areset(~n_reset_in), .inclk0(clk50M), .locked(pll0_locked),
	.c0(clk20M), .c1(clk10M), .c2(clk1M), .c3(clk140M));

`define NTSC	0
`define PAL		1
`define DENDY	2

logic clkMaster[3], clkPPU[3], clkCPU[3];
//assign clkMaster[`DENDY] = clkMaster[`PAL];
//assign clkPPU[`DENDY] = clkPPU[`PAL];
logic pll1_locked;
pll_ntsc pll1 (.areset(~n_reset_in), .inclk0(clk50M), .locked(pll1_locked),
	.c0(clkMaster[`NTSC]), .c1(clkPPU[`NTSC]), .c2(clkCPU[`NTSC]));
//pll_pal pll2 (.areset(~n_reset_in), .inclk0(clk50M), .c0(clkPPU[`PAL]), .c1(clkCPU[`DENDY]));

parameter clksel = `NTSC;

logic clk_Master, clk_PPU, clk_CPU;
assign clk_Master = clkMaster[clksel];
assign clk_PPU = clkPPU[clksel];
assign clk_CPU = clkCPU[clksel];

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

// Audio
logic [7:0] audio;
logic aout;
assign GPIO_0[25] = aout;
apu_pwm #(.N(8)) pwm0 (.n_reset(n_reset_in), .clk(clk10M), .cmp(audio), .q(aout), .en(1'b1), .*);

// SDRAM
logic clkSDRAM;
assign clkSDRAM = clk140M;

logic [23:0] addr_in;
logic [15:0] data_in;
assign data_in = 16'h0;
logic we, req;
logic rdy;

logic [23:0] addr_out;
logic [15:0] data_out;
logic rdy_out;

sdram #(.TINIT(14000), .TREFC(1093)) sdram0 (.n_reset(n_reset_in), .clk(clkSDRAM), .en(1'b1), .*);

// SDRAM cache
logic cache_we, cache_req;
assign cache_we = 1'b0;
logic cache_miss, cache_rdy;
logic [23:0] cache_addr;
wire [15:0] cache_data;
cache cache0 (.n_reset(n_reset_in), .clk(clkSDRAM),
	.we(cache_we), .req(cache_req), .miss(cache_miss), .rdy(cache_rdy),
	.addr(cache_addr), .data(cache_data),
	.if_addr_out(addr_in), .if_data_out(data_in),
	.if_we(we), .if_req(req), .if_rdy(rdy),
	.if_addr_in(addr_out), .if_data_in(data_out), .if_rdy_in(rdy_out)
);

// TFT
logic tft_en, tft_pixclk;
assign tft_en = SW[0], tft_pixclk = clk10M;
logic [23:0] tft_rgb;
logic [8:0] tft_x, tft_y;
tft #(.HN($clog2(480 - 1)), .VN($clog2(272 - 1)),
	.HT('{40, 1, 479, 1}), .VT('{10, 1, 271, 1})) tft0 (
	.n_reset(n_reset_in), .pixclk(tft_pixclk), .en(tft_en),
	.x(tft_x), .y(tft_y), .data(tft_rgb), .out(GPIO_1[23:0]),
	.disp(GPIO_1[24]), .de(GPIO_1[25]), .dclk(GPIO_1[28]),
	.vsync(GPIO_1[26]), .hsync(GPIO_1[27]));

// TFT pixel data generator
logic tft_update;
flag_detector tft_flag0 (.clk(clkSDRAM), .n_reset(n_reset_in), .flag(~tft_pixclk), .out(tft_update));

logic [23:0] tft_addr;
assign tft_addr = {6'h0, tft_y, tft_x};

always_ff @(posedge clkSDRAM, negedge n_reset_in)
	if (~n_reset_in) begin
		tft_rgb <= 24'h66ccff;
		cache_req <= 1'b0;
	end else if (tft_update) begin
		cache_req <= 1'b1;
	end else if (cache_rdy) begin
		tft_rgb <= {~tft_x[7:0], ~tft_y[7:0], tft_x[8:5], tft_y[8:5]}; //{data_out[15:11], 3'h0, data_out[10:5], 2'h0, data_out[4:0], 3'h0};
		cache_req <= 1'b0;
	end

assign cache_addr = tft_addr;

// System
logic [7:0] ppu_x, ppu_y;
logic [24:0] ppu_rgb;
system sys0 (.x(ppu_x), .y(ppu_y), .rgb(ppu_rgb), .*);

// Debug LEDs
assign LED[7:0] = {cache_req & cache_miss, req, rdy, GPIO_1[26], GPIO_1[27], aout, io[1][1:0]};

endmodule
