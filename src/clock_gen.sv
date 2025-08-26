module CLOCK_GEN #(
    parameter RESET_50_CYCLES = 16
) (
    input  wire  RESET_ASYNC_IN,

    input  wire  CLK_50,
    output wire  RESET_50_OUT,
    output wire  CLK_SYS,
    output wire  RESET_SYS_OUT,
    output wire  CLK_TFT,
    output wire  RESET_TFT_OUT,

    output wire  CLK_EMU,
    output wire  RESET_EMU_OUT,
    input  logic [1:0] VIDEO_MODE_IN,
    output logic VIDEO_TOGGLE_OUT,

    output logic PLL_LOCKED_OUT
);

logic reset_in;
CDC_ASYNC reset_cdc (
    .CLK        (CLK_50),
    .RESET_IN   ('0),
    .DATA_IN    (RESET_ASYNC_IN | ~PLL_LOCKED_OUT),
    .DATA_OUT   (reset_in)
);

logic [5:0] reset_cnt;

initial
    reset_cnt <= '1;

always @(posedge CLK_50)
    if (reset_in)
        reset_cnt <= '1;
    else if (reset_cnt != 0)
        reset_cnt <= reset_cnt - 1;

wire reset_pulse;
assign reset_pulse = ~reset_cnt[5];

CDC_ASYNC reset_sys (
    .CLK        (CLK_SYS),
    .RESET_IN   ('0),
    .DATA_IN    (reset_pulse),
    .DATA_OUT   (RESET_SYS_OUT)
);

CDC_ASYNC reset_lcd (
    .CLK        (CLK_TFT),
    .RESET_IN   ('0),
    .DATA_IN    (reset_pulse),
    .DATA_OUT   (RESET_TFT_OUT)
);

CDC_ASYNC reset_emu (
    .CLK        (CLK_EMU),
    .RESET_IN   ('0),
    .DATA_IN    (reset_pulse),
    .DATA_OUT   (RESET_EMU_OUT)
);

CDC_ASYNC reset_50 (
    .CLK        (CLK_50),
    .RESET_IN   ('0),
    .DATA_IN    (reset_pulse),
    .DATA_OUT   (RESET_50_OUT)
);

`ifndef SIMULATION

logic pll_sys_locked;
pll_sys pll_sys (
    .areset ('0),
    .inclk0 (CLK_50),
    .c0     (CLK_SYS),
    .c1     (CLK_EMU),
    .c2     (CLK_TFT),
    .locked (pll_sys_locked)
);

wire clk_ntsc_236, clk_pal_106;
logic pll_video_locked;
pll_video pll_video (
    .areset ('0),
    .inclk0 (CLK_50),
    .c0     (clk_ntsc_236),     // 236.25
    .c1     (clk_pal_106),      // 107.386360
    .locked (pll_video_locked)
);

CDC_ASYNC pll_locked_cdc (
    .CLK        (CLK_50),
    .RESET_IN   ('0),
    .DATA_IN    (pll_sys_locked | pll_video_locked),
    .DATA_OUT   (PLL_LOCKED_OUT)
);

logic reset_ntsc_236;
CDC_ASYNC reset_ntsc_236_cdc (
    .CLK        (CLK_50),
    .RESET_IN   ('0),
    .DATA_IN    (reset_pulse),
    .DATA_OUT   (reset_ntsc_236)
);

logic toggle_ntsc_21;
logic [3:0] div_ntsc_21_cnt;
always_ff @(posedge clk_ntsc_236, posedge reset_ntsc_236) begin
    if (reset_ntsc_236) begin
        toggle_ntsc_21 <= 0;
        div_ntsc_21_cnt <= 0;
    end else if (div_ntsc_21_cnt == 0) begin
        toggle_ntsc_21 <= ~toggle_ntsc_21;
        div_ntsc_21_cnt <= 10;
    end else begin
        div_ntsc_21_cnt <= div_ntsc_21_cnt - 1;
    end
end

logic reset_pal_106;
CDC_ASYNC reset_pal_106_cdc (
    .CLK        (CLK_50),
    .RESET_IN   ('0),
    .DATA_IN    (reset_pulse),
    .DATA_OUT   (reset_pal_106)
);

logic toggle_pal_27;
logic [1:0] div_pal_27_cnt;
always_ff @(posedge clk_pal_106, posedge reset_pal_106) begin
    if (reset_pal_106) begin
        toggle_pal_27 <= 0;
        div_pal_27_cnt <= 0;
    end else begin
        if (div_pal_27_cnt == 0)
            toggle_pal_27 <= ~toggle_pal_27;
        div_pal_27_cnt <= div_pal_27_cnt - 1;
    end
end

logic video_toggle;
assign video_toggle = VIDEO_MODE_IN == 0 ? toggle_ntsc_21 :
                      VIDEO_MODE_IN == 1 ? toggle_pal_27  : 0;

`else   // SIMULATION

assign PLL_LOCKED_OUT = '1;

// 143MHz system clock
logic clk_sys;
assign CLK_SYS    = clk_sys;
initial begin
    clk_sys = 0;
    forever begin
        #(0.5/142 * 1us) clk_sys = ~clk_sys;
        // #(0.5/100.0 * 1us) clk_sys = ~clk_sys;
    end
end

// 66.6MHz EMU clock
logic clk_emu;
assign CLK_EMU = clk_emu;
initial begin
    clk_emu = 0;
    forever
        #(0.5/66.6 * 1us) clk_emu = ~clk_emu;
end

// 33.3MHz TFT clock
logic clk_tft;
assign CLK_TFT = clk_tft;
initial begin
    clk_tft = 0;
    forever
        #(0.5/33.3 * 1us) clk_tft = ~clk_tft;
end

// Video master clock
logic video_toggle;
realtime video_period = 0;
initial begin
    video_toggle = 0;
    forever
        #video_period video_toggle = ~video_toggle;
end

always@(*) begin
    video_period = 1.0us;
    if (VIDEO_MODE_IN == 0)
        video_period = 1.0us / 236.25 * 11.0;
    else if (VIDEO_MODE_IN == 1)
        video_period = 1.0us / 26.6017125;
end

`endif  // SIMULATION

CDC_ASYNC #(
    .WIDTH  (1)
) video_toggle_cdc (
    .CLK        (CLK_EMU),
    .RESET_IN   (RESET_EMU_OUT),
    .DATA_IN    (video_toggle),
    .DATA_OUT   (VIDEO_TOGGLE_OUT)
);

endmodule
