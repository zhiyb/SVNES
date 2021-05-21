`timescale 100 ps / 100 ps

// vsim -gui -L altera_mf_ver work.TB_SDRAM_IO -t ns

module TB_TFT;

localparam TFT_W = 800;
localparam TFT_H = 480;

logic Clock;
logic Reset;

logic VBlank, HBlank;
logic [23:0] Colour, TpColour;

logic HwVSync, HwHSync;
logic [23:0] HwRgb;

TFT #(
    .HSYNC  (2),    .HBACK  (48),   .HDISP  (TFT_W),  .HFRONT (16),
    .VSYNC  (2),    .VBACK  (25),   .VDISP  (TFT_H),  .VFRONT (7),
    .WIDTH  (24)
) t0 (
    .CLK    (Clock),
    .CLK_IO (Clock),
    .RESET  (Reset),
    .EN     (1'b1),

    .VBLANK (VBlank),
    .HBLANK (HBlank),
    .COLOUR (Colour),

    .HW_DCLK    (),
    .HW_DISP    (),
    .HW_VSYNC   (HwVSync),
    .HW_HSYNC   (HwHSync),
    .HW_RGB     (HwRgb)
);

always_ff@(posedge Clock, posedge Reset)
    if (Reset)
        Colour <= 0;
    else if (VBlank)
        Colour <= 0;
    else if (~HBlank)
        Colour <= Colour + 1;

always@(*)
    assert(HwRgb < TFT_W * TFT_H)
    else $fatal(1, "Too many pixels");

initial
begin
    @(negedge Reset);
    @(negedge HwVSync);
    @(negedge HwVSync);
    @(negedge HwVSync);
    $finish(0);
end

TFT_TEST_PATTERN tp1
(
    .CLK    (Clock),
    .VBLANK (VBlank),
    .HBLANK (HBlank),
    .COLOUR (TpColour)
);

TFT #(
    .HSYNC  (2),    .HBACK  (48),   .HDISP  (TFT_W),  .HFRONT (16),
    .VSYNC  (2),    .VBACK  (25),   .VDISP  (TFT_H),  .VFRONT (7),
    .WIDTH  (24)
) t1 (
    .CLK    (Clock),
    .CLK_IO (Clock),
    .RESET  (Reset),
    .EN     (1'b1),

    .VBLANK (),
    .HBLANK (),
    .COLOUR (TpColour),

    .HW_DCLK    (),
    .HW_DISP    (),
    .HW_VSYNC   (),
    .HW_HSYNC   (),
    .HW_RGB     ()
);

initial
begin
    Reset = 1;
    Clock = 0;
    #7ns Reset = 0;
    // 30MHz TFT clock
    forever #16.5ns Clock = ~Clock;
end

initial
begin
    #50ms
    $info("Simulation timed out");
    $finish(1);
end

endmodule
