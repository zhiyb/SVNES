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

// IO connections

wire lcd_clk;
logic lcd_pwm, lcd_disp, lcd_hsync, lcd_vsync, lcd_de;
logic [7:0] lcd_red, lcd_green, lcd_blue;

assign GPIO_1[27] = lcd_clk;
assign GPIO_1[28] = lcd_disp;
assign GPIO_1[29] = lcd_hsync;
assign GPIO_1[31] = lcd_vsync;
assign GPIO_1[33] = lcd_de;
assign GPIO_1[26] = lcd_pwm;

assign {GPIO_1[8:6], GPIO_1[4:0]} = lcd_red;
assign {GPIO_1[17:13], GPIO_1[11:9]} = lcd_green;
assign {GPIO_1[25:18]} = lcd_blue;

logic [1:0] btn_disp;
assign btn_disp = {GPIO_1_IN[1], GPIO_1_IN[0]};

logic [1:0] led_disp;
assign {GPIO_1[12], GPIO_1[5]} = led_disp;

// Broken GPIOs:
// GPIO 1.5 stuck at 0v
// GPIO 1.12 stuck at 3v3
assign led_disp = 2'b10;
// assign led_disp = btn_disp;

logic hp_left, hp_right;
assign GPIO_1[30] = hp_left;
assign GPIO_1[32] = hp_right;

logic [7:0] btn_io;
assign btn_io = ~{GPIO_0[20], GPIO_0[21], GPIO_0[22], GPIO_0[23],
    GPIO_0[31], GPIO_0[32], GPIO_0[33], GPIO_0[30]};

typedef logic [2:0] rgb_led_t;
rgb_led_t [4:0] rgb_led;
assign {GPIO_0[7], GPIO_0[6], GPIO_0[5]} = rgb_led[0];
assign {GPIO_0[10], GPIO_0[9], GPIO_0[8]} = rgb_led[1];
assign {GPIO_0[13], GPIO_0[12], GPIO_0[11]} = rgb_led[2];
assign {GPIO_0[16], GPIO_0[15], GPIO_0[14]} = rgb_led[3];
assign {GPIO_0[19], GPIO_0[18], GPIO_0[17]} = rgb_led[4];

wire flash_clk;
logic flash_cs;
logic [3:0] flash_io;
assign GPIO_0[29] = flash_clk;
assign GPIO_0[27] = flash_cs;
assign {GPIO_0[26:24], GPIO_0[28]} = flash_io;


// 143MHz system clock
wire clk_sys, reset_sys;
// 33.3MHz TFT clock
wire clk_tft, reset_tft;
// Emulation CPU clock
wire clk_emu, reset_emu;
logic [1:0] video_mode;     // Video master clock selection
logic video_toggle;         // Video master clock toggle
logic pll_locked;

CLOCK_GEN clk (
    .RESET_ASYNC_IN (~KEY[0]),

    .CLK_50         (CLOCK_50),
    .RESET_50_OUT   (),
    .CLK_SYS        (clk_sys),
    .RESET_SYS_OUT  (reset_sys),
    .CLK_TFT        (clk_tft),
    .RESET_TFT_OUT  (reset_tft),

    .CLK_EMU          (clk_emu),
    .RESET_EMU_OUT    (reset_emu),
    .VIDEO_MODE_IN    (video_mode),
    .VIDEO_TOGGLE_OUT (video_toggle),

    .PLL_LOCKED_OUT (pll_locked)
);


// System AHB bus
localparam SDRAM_PORTS = 4;
localparam TFT_PORT    = 0;
localparam TP_PORT     = 3;

AHB_PKG::addr_t  [SDRAM_PORTS-1:0] haddr;
AHB_PKG::burst_t [SDRAM_PORTS-1:0] hburst;
AHB_PKG::size_t  [SDRAM_PORTS-1:0] hsize;
AHB_PKG::trans_t [SDRAM_PORTS-1:0] htrans;
logic            [SDRAM_PORTS-1:0] hwrite;
AHB_PKG::data_t  [SDRAM_PORTS-1:0] hwdata;
AHB_PKG::data_t  [SDRAM_PORTS-1:0] hrdata;
logic            [SDRAM_PORTS-1:0] hready;
AHB_PKG::resp_t  [SDRAM_PORTS-1:0] hresp;

assign htrans[1] = AHB_PKG::TRANS_IDLE;
assign htrans[2] = AHB_PKG::TRANS_IDLE;


// NES emulator
logic        nes_pixel_vblank;
logic        nes_pixel_valid;
logic [23:0] nes_pixel_rgb;
logic [7:0]  nes_debug;

NES_TOP #(
    .BOOTROM_PRG ("output_files/prg_rom"),
    .BOOTROM_CHR ("output_files/chr_rom")
) nes (
    .CLK_SYS          (clk_sys),
    .RESET_SYS_IN     (reset_sys),
    .CLK_EMU          (clk_emu),
    .RESET_EMU_IN     (reset_emu),
    .VIDEO_MODE_OUT   (video_mode),
    .VIDEO_TOGGLE_IN  (video_toggle),
    .PIXEL_VBLANK_OUT (nes_pixel_vblank),
    .PIXEL_VALID_OUT  (nes_pixel_valid),
    .PIXEL_RGB_OUT    (nes_pixel_rgb),
    .BUTTON_IN        (btn_io),
    .DEBUG_OUT        (nes_debug)
);

// NES screen to framebuffer
NES_DMA #(
    .BASE_ADDR (32'h08800000),
    .H_STRIP   (800),
    .X_OFFSET  (128),
    .Y_OFFSET  (128)
) nes_dma (
    .CLK             (clk_emu),
    .RESET_IN        (reset_emu),
    .PIXEL_VBLANK_IN (nes_pixel_vblank),
    .PIXEL_VALID_IN  (nes_pixel_valid),
    .PIXEL_RGB_IN    (nes_pixel_rgb),

    .HCLK            (clk_sys),
    .HRESET          (reset_sys),
    .HADDR           (haddr[TP_PORT]),
    .HBURST          (hburst[TP_PORT]),
    .HSIZE           (hsize[TP_PORT]),
    .HTRANS          (htrans[TP_PORT]),
    .HWRITE          (hwrite[TP_PORT]),
    .HWDATA          (hwdata[TP_PORT]),
    .HRDATA          (hrdata[TP_PORT]),
    .HREADY          (hready[TP_PORT]),
    .HRESP           (hresp[TP_PORT])
);


// SDRAM controller
localparam CLK_SDRAM_FREQ_MHZ = 143;
logic sdram_init_done;
SDRAM #(
    .AHB_PORTS     (SDRAM_PORTS),
    .N_CMD_QUEUES  (4),
    .N_CACHE_LINES (8),
    // Timing parameters
    .tRC   (9),
    .tRAS  (6),
    .tRP   (3),
    .tRCD  (3),
    .tMRD  (2),
    .tDPL  (2),
    .tQMD  (2),
    .tRRD  (2),
`ifndef SIMULATION
    .tINIT (CLK_SDRAM_FREQ_MHZ * 100),
    .tREF  (CLK_SDRAM_FREQ_MHZ * 64000 / 8192),
`else
    .tINIT (CLK_SDRAM_FREQ_MHZ * 1),
    .tREF  (CLK_SDRAM_FREQ_MHZ * 64000 / 8192),
`endif
    .CAS   (3),
    .BURST (8)
) sdram (
    .CLK            (clk_sys),
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


// // LCD test pattern generator
// logic [7:0] btn_io_sys;
// CDC_ASYNC #(
//     .WIDTH (8)
// ) tp_cdc (
//     .CLK        (clk_sys),
//     .RESET_IN   (reset_sys),
//     .DATA_IN    (btn_io),
//     .DATA_OUT   (btn_io_sys)
// );

// TEST_PATTERN_GEN #(
//     .WIDTH     (800),
//     .HEIGHT    (480),
//     .BPP       (32),
//     .BASE_ADDR (32'h08800000)
// ) tp (
//     .HCLK       (clk_sys),
//     .HRESET     (reset_sys),
//     .HADDR      (haddr[TP_PORT]),
//     .HBURST     (hburst[TP_PORT]),
//     .HSIZE      (hsize[TP_PORT]),
//     .HTRANS     (htrans[TP_PORT]),
//     .HWRITE     (hwrite[TP_PORT]),
//     .HWDATA     (hwdata[TP_PORT]),
//     .HRDATA     (hrdata[TP_PORT]),
//     .HREADY     (hready[TP_PORT]),
//     .HRESP      (hresp[TP_PORT]),

//     .START_IN   (btn_io_sys)
// );


// TFT LCD
logic tft_underflow;

TFT #(
    .BASE_ADDR  (32'h08800000),
`ifndef SIMULATION
    .HSYNC      (1),
    .HBACK      (46),
    .HDISP      (800),
    .HFRONT     (210),
    .VSYNC      (1),
    .VBACK      (23),
    .VDISP      (480),
    .VFRONT     (22),
`else
    .HSYNC      (1),
    .HBACK      (46),
    .HDISP      (800),
    .HFRONT     (21),
    .VSYNC      (1),
    .VBACK      (2),
    .VDISP      (48),
    .VFRONT     (2),
`endif
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

    .TFT_DCLK   (lcd_clk),
    .TFT_DISP   (lcd_disp),
    .TFT_VSYNC  (lcd_vsync),
    .TFT_HSYNC  (lcd_hsync),
    .TFT_RGB    ({lcd_red, lcd_green, lcd_blue})
);

assign lcd_de = 0;
assign lcd_pwm = 1;


// Debug LEDs
always_comb begin
    LED = 8'({tft_underflow, ~sdram_init_done, ~pll_locked});
    LED[7] = htrans[TP_PORT] != AHB_PKG::TRANS_IDLE;
    LED[6] = htrans[TFT_PORT] != AHB_PKG::TRANS_IDLE;
    LED ^= nes_debug;
end

logic [7:0] rgb_led_cnt;
logic rgb_led_pwm;

always_ff @(posedge CLOCK_50)
begin
    rgb_led_cnt <= rgb_led_cnt + 1;
    rgb_led_pwm <= rgb_led_cnt < 10;
end

assign rgb_led = (3*5)'({2{^btn_disp, btn_io}}) & {15{rgb_led_pwm}};

endmodule
