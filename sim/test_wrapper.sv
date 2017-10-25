`timescale 1 ps / 1 ps

module test_wrapper;

logic CLOCK_50;
logic [1:0] KEY;
logic [3:0] SW;
logic [7:0] LED;

logic [12:0] DRAM_ADDR;
logic [1:0] DRAM_BA, DRAM_DQM;
logic DRAM_CKE, DRAM_CLK;
logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;
wire [15:0] DRAM_DQ;

wire I2C_SCLK, I2C_SDAT;

logic G_SENSOR_CS_N;
logic G_SENSOR_INT;

logic ADC_CS_N, ADC_SADDR, ADC_SCLK;
logic ADC_SDAT;

wire [33:0] GPIO_0;
logic [1:0] GPIO_0_IN;
wire [33:0] GPIO_1;
logic [1:0] GPIO_1_IN;
wire [12:0] GPIO_2;
logic [2:0] GPIO_2_IN;

wrapper w0 (.*);

initial
begin
	KEY = 2'b00;
	#100ns KEY = 2'b11;
end

initial
begin
	CLOCK_50 = 1'b0;
	forever #10ns CLOCK_50 = ~CLOCK_50;
end

logic [15:0] DRAM_DQ_q;
assign DRAM_DQ = DRAM_DQ_q;

always_ff @(posedge DRAM_CLK, negedge KEY[0])
	if (~KEY[0])
		DRAM_DQ_q <= 16'h0;
	else
		DRAM_DQ_q <= DRAM_DQ_q + 1;

endmodule
