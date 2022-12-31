module TB_TFT;

initial
    #30ms $finish(0);

// 143MHz system clock
logic clk_sys;
initial
begin
    clk_sys = 0;
    forever
        #(0.5/143.0 * 1us) clk_sys = ~clk_sys;
end

logic reset_sys;
initial
begin
    reset_sys = 0;
    reset_sys = 1;
    @(posedge clk_sys);
    reset_sys = 0;
end

// 33.3MHz TFT clock
logic clk_tft;
initial
begin
    clk_tft = 0;
    forever
        #(0.5/33.3 * 1us) clk_tft = ~clk_tft;
end

logic reset_tft;
initial
begin
    reset_tft = 0;
    reset_tft = 1;
    @(negedge reset_sys);
    @(posedge clk_tft);
    reset_tft = 0;
end

// AHB memory DMA master
logic [31:0]     haddr;
AHB_PKG::burst_t hburst;
AHB_PKG::trans_t htrans;
logic            hwrite;
logic [31:0]     hwdata;
logic [31:0]     hrdata;
logic            hready;
logic            hresp;

// Status
logic underflow;

// Hardware IO
wire         TFT_DCLK;
logic        TFT_DISP, TFT_VSYNC, TFT_HSYNC;
logic [23:0] TFT_RGB;

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

    .UNDERFLOW_OUT  (underflow),

    .TFT_DCLK   (TFT_DCLK),
    .TFT_DISP   (TFT_DISP),
    .TFT_VSYNC  (TFT_VSYNC),
    .TFT_HSYNC  (TFT_HSYNC),
    .TFT_RGB    (TFT_RGB)
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
