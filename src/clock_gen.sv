module CLOCK_GEN #(
    parameter RESET_50_CYCLES = 16
) (
    input  wire  CLK_50,
    output wire  CLK_SYS,
    output wire  CLK_TFT,
    input  wire  RESET_ASYNC_IN,
    output wire  RESET_50_OUT,
    output wire  RESET_SYS_OUT,
    output wire  RESET_TFT_OUT
);

`ifndef SIMULATION

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

`endif  // SIMULATION

logic [1:0] reset_50_sync;
always_ff @(posedge CLK_50)
    {reset_50_sync} <= {reset_50_sync[0], RESET_ASYNC_IN};

wire   reset_50_cnt;
assign reset_50_cnt = reset_50_sync[1];

logic [$clog2(RESET_50_CYCLES)-1:0] reset_cnt;
always_ff @(posedge CLK_50, posedge reset_50_cnt)
    if (reset_50_cnt)
        reset_cnt <= RESET_50_CYCLES - 1;
    else if (reset_cnt != 0)
        reset_cnt <= reset_cnt - 1;

logic reset_50;
assign RESET_50_OUT = reset_50;
always_ff @(posedge CLK_50, posedge reset_50_cnt)
    if (reset_50_cnt)
        reset_50 <= 0;
    else
        reset_50 <= reset_cnt != 0;

logic [1:0] reset_sys_sync;
assign RESET_SYS_OUT = reset_sys_sync[1];
always_ff @(posedge CLK_SYS)
    {reset_sys_sync} <= {reset_sys_sync[0], RESET_50_OUT};

logic [1:0] reset_tft_sync;
assign RESET_TFT_OUT = reset_tft_sync[1];
always_ff @(posedge CLK_TFT)
    {reset_tft_sync} <= {reset_tft_sync[0], RESET_50_OUT};

endmodule
