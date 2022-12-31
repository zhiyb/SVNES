module WRAPPER (
    input  wire         CLOCK_50,
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

// 143MHz system clock
wire clk_sys, reset_sys;
// 33.3MHz TFT clock
wire clk_tft, reset_tft;

CLOCK_GEN clk (
    .CLK_50         (CLOCK_50),
    .CLK_SYS        (clk_sys),
    .CLK_TFT        (clk_tft),

    .RESET_ASYNC_IN (~KEY[0]),
    .RESET_50_OUT   (),
    .RESET_SYS_OUT  (reset_sys),
    .RESET_TFT_OUT  (reset_tft)
);

// AHB TFT DMA bus
logic [31:0]     haddr;
AHB_PKG::burst_t hburst;
AHB_PKG::trans_t htrans;
logic            hwrite;
logic [31:0]     hwdata;
logic [31:0]     hrdata;
logic            hready;
logic            hresp;

TFT #(
    .BASE_ADDR  (32'h0f000000),
    .HSYNC      (2),
    .HBACK      (44),
    .HDISP      (800),
    .HFRONT     (16),
    .VSYNC      (2),
    .VBACK      (21),
    .VDISP      (480),
    .VFRONT     (7),
    .TFT_WIDTH  (24)
) tft (
    .CLK_TFT    (clk_tft),
    .RESET_TFT  (reset_tft),

    .HCLK       (clk_sys),
    .HRESET     (reset_sys),
    .HADDR      (haddr),
    .HBURST     (hburst),
    .HTRANS     (htrans),
    .HWRITE     (hwrite),
    .HWDATA     (hwdata),
    .HRDATA     (hrdata),
    .HREADY     (hready),
    .HRESP      (hresp),

    .UNDERFLOW_OUT  (LED[0]),

    .TFT_DCLK   (GPIO_0[29]),
    .TFT_DISP   (GPIO_0[30]),
    .TFT_VSYNC  (GPIO_0[33]),
    .TFT_HSYNC  (GPIO_0[31]),
    .TFT_RGB    ({GPIO_0[7:0], GPIO_0[18:16], GPIO_0[14:13], GPIO_0[11:10], GPIO_0[8], GPIO_0[28], GPIO_0[26:21], GPIO_0[19]})
);

// Test pattern generator
TFT_PATTERN_GEN #(
    .BASE_ADDR      (32'h0f000000),
    .WIDTH          (800),
    .HEIGHT         (480),
    .PIXEL_WIDTH    (24)
) ptn (
    .HCLK   (clk_sys),
    .HRESET (reset_sys),
    .HADDR  (haddr),
    .HBURST (hburst),
    .HTRANS (htrans),
    .HWRITE (hwrite),
    .HWDATA (hwdata),
    .HRDATA (hrdata),
    .HREADY (hready),
    .HRESP  (hresp)
);

endmodule
