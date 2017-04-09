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
logic clk10M, clk32M, clk50M, clk96M, clk192M, clk240M;
assign clk50M = CLOCK_50;
pll pll0 (.inclk0(clk50M), .locked(),
	.c0(clk10M), .c1(clk32M), .c2(clk96M), .c3(clk192M), .c4(clk240M));

logic clkSYS, clkSDRAM, clkTFT;
//assign clkSYS = clk240M;
assign clkSDRAM = clk96M;
assign clkTFT = clk32M;

// Reset control
logic n_reset;
logic n_reset_ext, n_reset_mem;

always_ff @(posedge clk50M)
begin
	n_reset_ext <= KEY[0];
	n_reset <= n_reset_ext & n_reset_mem;
end

// System interface clock switch for debugging
logic [1:0] clk;
logic [23:0] cnt;
always_ff @(posedge clk10M, negedge n_reset)
	if (~n_reset) begin
		cnt <= 0;
		clk <= 0;
	end else if (cnt == 0) begin
		cnt <= 10000000;
		clk <= KEY[1] ? clk : clk + 1;
	end else
		cnt <= cnt - 1;

logic sys[4];
assign sys[0] = clk240M;
assign sys[1] = clk192M;
assign sys[2] = clk96M;
assign sys[3] = clk192M;
assign clkSYS = sys[clk];

// Memory interface
parameter AN = 24, DN = 16, BURST = 8;
parameter logic [1:0] id_tft = 2'b11;

logic [DN - 1:0] mem_data;
logic [1:0] mem_id;
logic mem_valid;

logic [AN - 1:0] req_addr, tft_addr;
logic [1:0] req_id;
logic request, tft_request;
logic req_wr;
logic req_ack, tft_ack;

logic req_ack_latch;
always_ff @(posedge clkSYS)
	req_ack_latch <= req_ack;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		request <= 1'b0;
		req_addr <= {AN{1'b0}};
		req_id <= 2'b00;
		req_wr <= 1'b0;
	end else if (req_ack || req_ack_latch)
		request <= 1'b0;
	else if (~request) begin
		// Priority
		if (tft_request) begin
			request <= 1'b1;
			req_addr <= tft_addr;
			req_id <= id_tft;
			req_wr <= 1'b0;
		end else begin
			request <= 1'b0;
			req_addr <= 'x;
			req_id <= 'x;
			req_wr <= 'x;
		end
	end

always_ff @(posedge clkSYS)
	tft_ack <= req_ack && req_id == id_tft;

logic [DN - 1:0] tft_mem_data;
logic tft_mem_valid;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		tft_mem_data <= 0;
		tft_mem_valid <= 1'b0;
	end else if (mem_id == id_tft) begin
		tft_mem_data <= mem_data;
		tft_mem_valid <= mem_valid;
	end

// SDRAM
logic [1:0] sdram_level;
logic sdram_empty, sdram_full;
`ifdef MODEL_TECH
sdram #(.AN(AN), .DN(DN), .BURST(BURST), .tINIT(10)) sdram0
`else
sdram #(.AN(AN), .DN(DN), .BURST(BURST)) sdram0
`endif
	(clkSYS, clkSDRAM, n_reset_ext, n_reset_mem,
	mem_data, mem_id, mem_valid,
	req_addr, 16'h0, req_id, request, req_wr, req_ack,
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
	.mem_data(tft_mem_data), .mem_valid(tft_mem_valid),
	.req_addr(tft_addr), .req_ack(tft_ack), .request(tft_request),
	.disp(GPIO_0[26]), .de(GPIO_0[29]), .dclk(GPIO_0[25]),
	.vsync(GPIO_0[28]), .hsync(GPIO_0[27]),
	.out({GPIO_0[7:0], GPIO_0[15:8], GPIO_0[23:16]}),
	.level(tft_level), .empty(tft_empty), .full(tft_full));

logic tft_pwm;
assign GPIO_0[24] = tft_pwm;
assign tft_pwm = n_reset;

// Debugging LEDs
assign LED[7:0] = {clk, sdram_full, sdram_empty, tft_full, tft_empty, tft_level[5:4]};

endmodule
