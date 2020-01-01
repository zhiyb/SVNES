module PLATFORM_DE0_NANO (
    input  wire         CLOCK_50,
    input  logic  [1:0] KEY,
    input  logic  [3:0] SW,
    output logic  [7:0] LED,
    
    output logic [12:0] DRAM_ADDR,
    output logic  [1:0] DRAM_BA, DRAM_DQM,
    output logic        DRAM_CKE, DRAM_CLK,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
    inout  wire  [15:0] DRAM_DQ,
    
    inout  wire         I2C_SCLK, I2C_SDAT,
    
    output logic        G_SENSOR_CS_N,
    input  logic        G_SENSOR_INT,
    
    output logic        ADC_CS_N, ADC_SADDR, ADC_SCLK,
    input  logic        ADC_SDAT,
    
    inout  wire  [33:0] GPIO_0,
    input  logic  [1:0] GPIO_0_IN,
    inout  wire  [33:0] GPIO_1,
    input  logic  [1:0] GPIO_1_IN,
    inout  wire  [12:0] GPIO_2,
    input  logic  [2:0] GPIO_2_IN
);

// Registers should be initialised to 0 after configuration
logic ResetInit;
always_ff @(posedge CLOCK_50)
    ResetInit <= 1;

// Clock tree
wire  ClkSDRAMIO, ClkSDRAM, Clk10M, ClkTFT, ClkSYS;
logic PllLocked;

PLL_MAIN pll_main (
    .CLK_IN (CLOCK_50),
    .RESET  (ResetInit),
    .CLK_OUT({ClkSYS, ClkTFT, Clk10M, ClkSDRAM, ClkSDRAMIO}),
    .LOCKED (PllLocked)
);

// Reset control
logic ResetAsync;
assign ResetAsync = ResetInit & PllLocked;

// TFT display
logic ResetTFT, ResetTFTPipe;
always_ff @(posedge ClkTFT, negedge ResetAsync)
    if (~ResetAsync)
        {ResetTFT, ResetTFTPipe} <= 0;
    else
        {ResetTFT, ResetTFTPipe} <= {ResetTFTPipe, ResetAsync};

// Test pattern
logic VBlank, HBlank;
logic z1_HBlank;
logic [9:0] x;
logic [8:0] y;

always_ff @(posedge ClkTFT)
    z1_HBlank <= HBlank;

always_ff @(posedge ClkTFT)
    if (VBlank)
        y <= 0;
    else if (~z1_HBlank & HBlank)
        y <= y + 1;

always_ff @(posedge ClkTFT)
    if (HBlank)
        x <= 0;
    else
        x <= x + 1;

logic [7:0] r, g, b;
always_comb
begin
    r = {x[8 +: 2], 6'b0};
    g = x[7:0];
    b = y[7:0];
    if (x == 0)
        {r, g, b} = 24'hff0000;
    else if (x == 799)
        {r, g, b} = 24'h00ff00;
    if (y == 0)
        {r, g, b} = 24'h0000ff;
    else if (y == 479)
        {r, g, b} = 24'hffff00;
end

//TFT #(.1, 40, 479, 1}, 10, '{1, 9, 271, 1}) tft0
TFT #(
`ifdef MODEL_TECH
    .HSYNC  (2),    .HBACK  (3),   .HDISP  (4),  .HFRONT (5),
    .VSYNC  (2),    .VBACK  (3),   .VDISP  (4),  .VFRONT (5),
`else
    .HSYNC  (2),    .HBACK  (48),   .HDISP  (800),  .HFRONT (16),
    .VSYNC  (2),    .VBACK  (25),   .VDISP  (480),  .VFRONT (7),
`endif
    .WIDTH  (24)
) tft0 (
    .CLK    (ClkTFT),
    .RESET  (ResetTFT),
    .EN     (1'b1),

    .VBLANK (VBlank),
    .HBLANK (HBlank),
    .COLOUR ({r, g, b}),

    // Hardware IO
    .HW_DCLK    (GPIO_0[29]),
    .HW_DISP    (GPIO_0[30]),
    .HW_VSYNC   (GPIO_0[33]),
    .HW_HSYNC   (GPIO_0[31]),
    .HW_RGB     ({{GPIO_0[7:0]},
                  {GPIO_0[18:16], GPIO_0[14:13], GPIO_0[11:10], GPIO_0[8]},
                  {GPIO_0[28], GPIO_0[26:21], GPIO_0[19]}})
);

assign LED[7:0] = {ResetTFT, VBlank, HBlank, ClkSDRAMIO, ClkSDRAM, Clk10M, ClkTFT, ClkSYS};

endmodule
