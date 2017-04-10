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
);

// Clocks
logic clk10M, clk30M, clk50M, clk90M, clk270M, clk360M;
assign clk50M = CLOCK_50;
pll pll0 (.inclk0(clk50M), .locked(),
	.c0(clk10M), .c1(clk30M), .c2(clk90M), .c3(clk270M), .c4(clk360M));

logic clkSYS, clkSDRAM, clkTFT;
//assign clkSYS = clk360M;
assign clkSDRAM = clk90M;
assign clkTFT = clk30M;

// Reset control
logic n_reset;
logic n_reset_ext, n_reset_mem;

always_ff @(posedge clk50M)
begin
	n_reset_ext <= KEY[0];
	n_reset <= n_reset_ext & n_reset_mem;
end

// System interface clock switch for debugging
`ifdef MODEL_TECH
logic [1:0] clk;
assign clk = 0;
assign clkSYS = clk360M;
`else
logic [1:0] clk;
logic [23:0] cnt;
always_ff @(posedge clk10M)
	if (cnt == 0) begin
		cnt <= 10000000;
		clk <= KEY[1] ? clk : clk + 1;
	end else
		cnt <= cnt - 1;

logic sys[4];
assign sys[0] = clk360M;
assign sys[1] = clk270M;
assign sys[2] = clk90M;
assign sys[3] = clk270M;
assign clkSYS = sys[clk];
`endif

// Memory interface and arbiter
parameter AN = 24, DN = 16, BURST = 8;

logic [DN - 1:0] mem_data;
logic [1:0] mem_id;

arbiter_if #(AN, DN, 2) mem ();
arbiter_if #(AN, DN, 2) arb[4] ();
arbiter_sync_pri #(AN, DN, 2) arb0 (clkSYS, n_reset,
	mem, mem_data, mem_id, arb);

assign arb[0].req = 0;
assign arb[1].req = 0;
`define tft arb[2]
`define test arb[3]

// SDRAM
logic [1:0] sdram_level;
logic sdram_empty, sdram_full;
sdram #(.AN(AN), .DN(DN), .BURST(BURST)) sdram0
	(clkSYS, clkSDRAM, n_reset_ext, n_reset_mem,
	mem_data, mem_id, mem.valid,
	mem.addr, mem.data, mem.id, mem.req, mem.wr, mem.ack,
	DRAM_DQ, DRAM_ADDR, DRAM_BA, DRAM_DQM,
	DRAM_CLK, DRAM_CKE, DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	sdram_empty, sdram_full, sdram_level);

// TFT
logic [5:0] tft_level;
logic tft_empty, tft_full;
`ifdef MODEL_TECH
tft #(AN, DN, BURST, 24'hfa0000, 10, '{1, 1, 256, 1}, 10, '{1, 1, 128, 1}) tft0
`else
tft #(AN, DN, BURST, 24'hfa0000, 10, '{1, 43, 799, 15}, 10, '{1, 20, 479, 6}) tft0
`endif
	(.clkSYS(clkSYS), .clkTFT(clkTFT), .n_reset(n_reset),
	.mem_data(`tft.mem), .mem_valid(`tft.valid),
	.req_addr(`tft.addr), .req_ack(`tft.ack), .req(`tft.req),
	.disp(GPIO_0[26]), .de(GPIO_0[29]), .dclk(GPIO_0[25]),
	.vsync(GPIO_0[28]), .hsync(GPIO_0[27]),
	.out({GPIO_0[7:0], GPIO_0[15:8], GPIO_0[23:16]}),
	.level(tft_level), .empty(tft_empty), .full(tft_full));

assign `tft.data = 'x;
assign `tft.wr = 0;

logic tft_pwm;
assign GPIO_0[24] = tft_pwm;
assign tft_pwm = n_reset;

// Memory RW test client
logic test_fail;
`ifdef MODEL_TECH
mem_test #(BURST, 24'hfb0000, 24'h000010) test0 (clkSYS, n_reset, `test.mem, `test.valid,
	`test.addr, `test.data, `test.req, `test.wr, `test.ack, test_fail, ~KEY[1], SW[3]);
`else
mem_test #(BURST, 24'hfb0000, 24'h040000) test0 (clkSYS, n_reset, `test.mem, `test.valid,
	`test.addr, `test.data, `test.req, `test.wr, `test.ack, test_fail, ~KEY[1], SW[3]);
`endif

// Debugging LEDs
assign LED[7:0] = {clk, test_fail, sdram_empty, sdram_level[1], tft_empty, tft_level[5:4]};

endmodule
