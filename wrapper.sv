module wrapper (
	input logic CLOCK_50,
	input logic [1:0] KEY,
	input logic [3:0] SW,
	output logic [7:0] LED,
	
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_CAS_N, DRAM_RAS_N, DRAM_WE_N,
	inout logic [15:0] DRAM_DQ,
	
	inout logic I2C_SCLK, I2C_SDAT,
	
	output logic G_SENSOR_CS_N,
	input logic G_SENSOR_INT,
	
	output logic ADC_CS_N, ADC_SADDR, ADC_SCLK,
	input logic ADC_SDAT,
	
	inout logic [33:0] GPIO_0,
	input logic [1:0] GPIO_0_IN,
	inout logic [33:0] GPIO_1,
	input logic [1:0] GPIO_1_IN,
	inout logic [12:0] GPIO_2,
	input logic [2:0] GPIO_2_IN
);

logic n_reset, clk1, clk1M, clk50M;

assign n_reset = KEY[1];
assign clk50M = CLOCK_50;

counter #(.n($clog2(50 - 1))) p0 (.top(50 - 1), .clk(clk50M), .n_reset(n_reset), .out(clk1M));
counter #(.n($clog2(50000000 - 1))) p1 (.top(50000000 - 1), .clk(clk50M), .n_reset(n_reset), .out(clk1));

logic [7:0] cnt;

always_ff @(posedge clk1, negedge n_reset)
	if (~n_reset)
		cnt <= 'b0;
	else
		cnt <= cnt + 1'b1;

assign LED = cnt;

endmodule
