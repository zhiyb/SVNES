module WRAPPER (
    input  wire         CLOCK_50,
    input  logic [1:0]  KEY,
    input  logic [3:0]  SW,
    output logic [7:0]  LED,

    output wire         DRAM_CLK,
    output logic        DRAM_CKE,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
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
// Clock for SDRAM CLK pin
wire clk_mem_io;
// 33.3MHz TFT clock
wire clk_tft, reset_tft;
logic pll_locked;

CLOCK_GEN clk (
    .CLK_50         (CLOCK_50),
    .CLK_SYS        (clk_sys),
    .CLK_MEM_IO     (clk_mem_io),
    .CLK_TFT        (clk_tft),

    .RESET_ASYNC_IN (~KEY[0]),
    .RESET_50_OUT   (),
    .RESET_SYS_OUT  (reset_sys),
    .RESET_TFT_OUT  (reset_tft),

    .PLL_LOCKED_OUT (pll_locked)
);

// System AHB bus
localparam SDRAM_PORTS = 4;
localparam TFT_PORT    = 3;

AHB_PKG::addr_t  [SDRAM_PORTS-1:0] haddr;
AHB_PKG::burst_t [SDRAM_PORTS-1:0] hburst;
AHB_PKG::size_t  [SDRAM_PORTS-1:0] hsize;
AHB_PKG::trans_t [SDRAM_PORTS-1:0] htrans;
logic            [SDRAM_PORTS-1:0] hwrite;
AHB_PKG::data_t  [SDRAM_PORTS-1:0] hwdata;
AHB_PKG::data_t  [SDRAM_PORTS-1:0] hrdata;
logic            [SDRAM_PORTS-1:0] hready;
AHB_PKG::resp_t  [SDRAM_PORTS-1:0] hresp;

assign htrans[0] = AHB_PKG::TRANS_IDLE;
assign htrans[1] = AHB_PKG::TRANS_IDLE;
assign htrans[2] = AHB_PKG::TRANS_IDLE;

// SDRAM controller
logic sdram_init_done;
SDRAM #(
    .AHB_PORTS  (SDRAM_PORTS),
    .tRC        (9),
    .tRAS       (6),
    .tRP        (3),
    .tRCD       (3),
    .tMRD       (2),
    .tDPL       (2),
    .tQMD       (2),
    .tRRD       (2),
    .tINIT      (14250),
    .tREF       (1114),
    .CAS        (3),
    .BURST      (8)
) sdram (
    .CLK            (clk_sys),
    .CLK_IO         (clk_mem_io),
    .RESET_IN       (reset_sys),

    .INIT_DONE_OUT  (sdram_init_done),

    .HADDR          (haddr),
    .HBURST         (hburst),
    .HSIZE          (hsize),
    .HTRANS         (htrans),
    .HWRITE         (hwrite),
    .HWDATA         (hwdata),
    .HRDATA         (hrdata),
    .HREADY         (hready),
    .HRESP          (hresp),

    .DRAM_CLK       (DRAM_CLK),
    .DRAM_CKE       (DRAM_CKE),
    .DRAM_DQ        (DRAM_DQ),
    .DRAM_ADDR      (DRAM_ADDR),
    .DRAM_BA        (DRAM_BA),
    .DRAM_DQM       (DRAM_DQM),
    .DRAM_CS_N      (DRAM_CS_N),
    .DRAM_RAS_N     (DRAM_RAS_N),
    .DRAM_CAS_N     (DRAM_CAS_N),
    .DRAM_WE_N      (DRAM_WE_N)
);

logic tft_underflow;

TFT #(
    .BASE_ADDR  (32'h0f000000),
    .HSYNC      (1),
    .HBACK      (45),
    .HDISP      (800),
    .HFRONT     (210),
    .VSYNC      (1),
    .VBACK      (23),
    .VDISP      (480),
    .VFRONT     (22),
    .TFT_WIDTH  (24)
) tft (
    .CLK_TFT    (clk_tft),
    .RESET_TFT  (reset_tft),

    .HCLK       (clk_sys),
    .HRESET     (reset_sys),
    .HADDR      (haddr[TFT_PORT]),
    .HBURST     (hburst[TFT_PORT]),
    .HSIZE      (hsize[TFT_PORT]),
    .HTRANS     (htrans[TFT_PORT]),
    .HWRITE     (hwrite[TFT_PORT]),
    .HWDATA     (hwdata[TFT_PORT]),
    .HRDATA     (hrdata[TFT_PORT]),
    .HREADY     (hready[TFT_PORT]),
    .HRESP      (hresp[TFT_PORT]),

    .UNDERFLOW_OUT  (tft_underflow),

    .TFT_DCLK   (GPIO_0[29]),
    .TFT_DISP   (GPIO_0[30]),
    .TFT_VSYNC  (GPIO_0[33]),
    .TFT_HSYNC  (GPIO_0[31]),
    .TFT_RGB    ({GPIO_0[7:0], GPIO_0[18:16], GPIO_0[14:13], GPIO_0[11:10], GPIO_0[8], GPIO_0[28], GPIO_0[26:21], GPIO_0[19]})
);

// Debug LEDs
assign LED = 8'({tft_underflow, ~sdram_init_done, ~pll_locked});

endmodule
