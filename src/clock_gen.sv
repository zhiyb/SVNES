module CLOCK_GEN #(
    parameter RESET_50_CYCLES = 16
) (
    input  wire  CLK_50,
    output wire  CLK_SYS,
    output wire  CLK_TFT,
    input  wire  RESET_ASYNC_IN,
    output wire  RESET_50_OUT,
    output wire  RESET_SYS_OUT,
    output wire  RESET_TFT_OUT,
    output logic PLL_LOCKED_OUT
);

wire reset_pll;

`ifndef SIMULATION

pll_sys pll0 (
    .areset (reset_pll),
    .inclk0 (CLK_50),
    .c0     (CLK_SYS),
    .c1     (CLK_TFT),
    .locked (PLL_LOCKED_OUT)
);

`else   // SIMULATION

// 143MHz system clock
logic clk_sys;
assign CLK_SYS = clk_sys;
initial begin
    clk_sys = 0;
    forever
        #(0.5/143.0 * 1us) clk_sys = ~clk_sys;
end

// 33.3MHz TFT clock
logic clk_tft;
assign CLK_TFT = clk_tft;
initial begin
    clk_tft = 0;
    forever
        #(0.5/33.3 * 1us) clk_tft = ~clk_tft;
end

assign PLL_LOCKED_OUT = '1;

`endif  // SIMULATION

// RESET_ASYNC_IN -> reset_50_pll

wire reset_50_cnt;
CDC_ASYNC #(
    .WIDTH  (1)
) cdc_50_cnt (
    .SRC_CLK        (1'b0),
    .SRC_RESET_IN   (1'b0),
    .SRC_DATA_IN    (RESET_ASYNC_IN),
    .DST_CLK        (CLK_50),
    .DST_RESET_IN   (1'b0),
    .DST_DATA_OUT   (reset_50_cnt)
);

logic [$clog2(RESET_50_CYCLES)-1:0] reset_cnt;
always_ff @(posedge CLK_50, posedge reset_50_cnt)
    if (reset_50_cnt)
        reset_cnt <= RESET_50_CYCLES - 1;
    else if (reset_cnt != 0)
        reset_cnt <= reset_cnt - 1;

logic reset_50_pll;
assign reset_pll = reset_50_pll;
always_ff @(posedge CLK_50, posedge reset_50_cnt)
    if (reset_50_cnt)
        reset_50_pll <= 0;
    else
        reset_50_pll <= reset_cnt != 0;

// reset_50_pll -> RESET_50_OUT

wire locked_50;
CDC_ASYNC #(
    .WIDTH  (1)
) cdc_50_locked (
    .SRC_CLK        (1'b0),
    .SRC_RESET_IN   (1'b0),
    .SRC_DATA_IN    (PLL_LOCKED_OUT),
    .DST_CLK        (CLK_50),
    .DST_RESET_IN   (1'b0),
    .DST_DATA_OUT   (locked_50)
);

logic [$clog2(RESET_50_CYCLES)-1:0] reset_50_pll_cnt;
always_ff @(posedge CLK_50, posedge reset_50_pll)
    if (reset_50_pll)
        reset_50_pll_cnt <= RESET_50_CYCLES - 1;
    else if (reset_50_pll_cnt != 0)
        reset_50_pll_cnt <= reset_50_pll_cnt - 1;

wire reset_50;
assign RESET_50_OUT = reset_50;
always_ff @(posedge CLK_50, posedge reset_50_pll)
    if (reset_50_pll)
        reset_50 <= 0;
    else if (reset_50_pll_cnt != 0 || ~locked_50)
        reset_50 <= 1;
    else
        reset_50 <= 0;

// RESET_50_OUT -> RESET_SYS_OUT

wire reset_sys;
assign RESET_SYS_OUT = reset_sys;
CDC_ASYNC #(
    .WIDTH  (1)
) cdc_sys (
    .SRC_CLK        (CLK_50),
    .SRC_RESET_IN   (1'b0),
    .SRC_DATA_IN    (RESET_50_OUT),
    .DST_CLK        (CLK_SYS),
    .DST_RESET_IN   (1'b0),
    .DST_DATA_OUT   (reset_sys)
);

// RESET_50_OUT -> RESET_TFT_OUT

wire reset_tft;
assign RESET_TFT_OUT = reset_tft;
CDC_ASYNC #(
    .WIDTH  (1)
) cdc_tft (
    .SRC_CLK        (CLK_50),
    .SRC_RESET_IN   (1'b0),
    .SRC_DATA_IN    (RESET_50_OUT),
    .DST_CLK        (CLK_TFT),
    .DST_RESET_IN   (1'b0),
    .DST_DATA_OUT   (reset_tft)
);

endmodule
