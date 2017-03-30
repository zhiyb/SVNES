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
logic clk10M, clk32M, clk50M, clk96M, clk192M;
assign clk50M = CLOCK_50;
pll pll0 (.inclk0(clk50M), .locked(),
	.c0(clk10M), .c1(clk32M), .c2(clk96M), .c3(clk192M));

logic clkSYS, clkSDRAM, clkTFT;
assign clkSYS = clk192M;
assign clkSDRAM = clk96M;
assign clkTFT = clk32M;

// Reset control
logic n_reset;
logic n_reset_ext, n_reset_mem;
assign n_reset_ext = KEY[0];

always_ff @(posedge clk50M)
	n_reset = n_reset_ext;

// Memory interface
parameter AN = 22, DN = 16, BURST = 8;

logic [DN - 1:0] mem_data;
logic [1:0] mem_id;
logic mem_valid;

logic [AN - 1:0] req_addr, tft_addr;
logic request, tft_request;
logic [1:0] req_id;
logic req_ready, tft_ready;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		request <= 1'b0;
		req_addr <= {AN{1'b0}};
		req_id <= 2'b00;
	end else if (req_ready) begin
		// Priority
		if (tft_request) begin
			request <= 1'b1;
			req_addr <= tft_addr;
			req_id <= 2'b11;
		end
	end else begin
		request <= 1'b0;
	end

always_ff @(posedge clkSYS)
begin
	tft_ready <= request && req_ready && req_id == 2'b11;
end

// Memory tests
logic [2:0] burst;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		mem_data <= 0;
		mem_valid <= 1'b0;
		mem_id <= 2'h0;
		burst <= 0;
		req_ready <= 1'b0;
	end else if (request && req_ready) begin
		mem_data <= req_addr[15:0];
		mem_valid <= 1'b1;
		mem_id <= req_id;
		burst <= BURST - 1;
		req_ready <= 1'b0;
	end else if (burst == 0) begin
		mem_valid <= 1'b0;
		req_ready <= 1'b1;
	end else begin
		mem_data <= mem_data + 1;
		mem_valid <= 1'b1;
		burst <= burst - 1;
		req_ready <= 1'b0;
	end

// SDRAM
//sdram #(AN, DN) sdram0 (.clkSYS(clkSYS), .clkSDRAM(clkSDRAM));

// TFT
logic [5:0] tft_level;
logic tft_empty, tft_full;
tft #(AN, DN, BURST, 22'h3a0000,
	10, '{1, 43, 799, 15}, 10, '{1, 20, 479, 6}) tft0
	(.clkSYS(clkSYS), .clkTFT(clkTFT), .n_reset(n_reset),
	.mem_data(mem_data), .mem_valid(mem_valid),
	.req_addr(tft_addr), .req_ready(tft_ready), .request(tft_request),
	.disp(GPIO_0[26]), .de(GPIO_0[29]), .dclk(GPIO_0[25]),
	.vsync(GPIO_0[28]), .hsync(GPIO_0[27]),
	.out({GPIO_0[7:0], GPIO_0[15:8], GPIO_0[23:16]}),
	.level(tft_level), .empty(tft_empty), .full(tft_full));

logic tft_pwm;
assign GPIO_0[24] = tft_pwm;
assign tft_pwm = 1'b1;

// Debugging LEDs
assign LED[7:0] = {tft_full, tft_empty, tft_level[5:0]};

endmodule
