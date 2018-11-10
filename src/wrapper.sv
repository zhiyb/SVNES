module wrapper
(
    input  logic        CLOCK_50,
    input  logic [1:0]  KEY,
    input  logic [3:0]  SW,
    output logic [7:0]  LED,
    
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output logic        DRAM_CKE, DRAM_CLK,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
    inout  wire  [15:0] DRAM_DQ,
    
    inout  wire         I2C_SCLK, I2C_SDAT,
    
    output logic        G_SENSOR_CS_N,
    input  logic        G_SENSOR_INT,
    
    output logic        ADC_CS_N, ADC_SADDR, ADC_SCLK,
    input  logic        ADC_SDAT,
    
    inout  wire  [33:0] GPIO_0,
    input  logic [1:0]  GPIO_0_IN,
    inout  wire  [33:0] GPIO_1,
    input  logic [1:0]  GPIO_1_IN,
    inout  wire  [12:0] GPIO_2,
    input  logic [2:0]  GPIO_2_IN
);

endmodule
