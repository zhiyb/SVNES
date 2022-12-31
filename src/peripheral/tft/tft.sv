module TFT #(
    // DMA base address
    parameter logic [31:0] BASE_ADDR = 0,
    // Horizontal & vertical: sync width, back porch, display, front porch
    parameter HSYNC, HBACK, HDISP, HFRONT,
    parameter VSYNC, VBACK, VDISP, VFRONT,
    // Pixel RGB output width
    parameter TFT_WIDTH = 24
) (
    input  wire CLK_TFT,
    input  wire RESET_TFT,

    // Status report
    output logic            UNDERFLOW_OUT,

    // AHB memory DMA master
    input  wire             HCLK,
    input  wire             HRESET,
    output logic [31:0]     HADDR,
    output AHB_PKG::burst_t HBURST,
    output AHB_PKG::trans_t HTRANS,
    output logic            HWRITE,
    output logic [31:0]     HWDATA,
    input  logic [31:0]     HRDATA,
    input  logic            HREADY,
    input  logic            HRESP,

    // Hardware IO
    output wire  TFT_DCLK,
    output logic TFT_DISP, TFT_VSYNC, TFT_HSYNC,
    output logic [TFT_WIDTH-1:0] TFT_RGB
);

// AHB CDC
logic vsync_ahb, vsync_sync, vsync_tft;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        {vsync_ahb, vsync_sync} <= 0;
    else
        {vsync_ahb, vsync_sync} <= {vsync_sync, vsync_tft};

logic [31:0] dma_data_ahb;
logic dma_req_ahb, dma_ack_ahb;

logic [31:0] dma_data_tft;
logic dma_req_tft, dma_ack_tft;

FIFO_ASYNC #(
    .DATA_T (logic [31:0])
) fifo (
    .WRITE_CLK      (HCLK),
    .WRITE_RESET_IN (HRESET),
    .WRITE_DATA_IN  (dma_data_ahb),
    .WRITE_REQ_IN   (dma_req_ahb),
    .WRITE_ACK_OUT  (dma_ack_ahb),

    .READ_CLK       (CLK_TFT),
    .READ_RESET_IN  (RESET_TFT),
    .READ_DATA_OUT  (dma_data_tft),
    .READ_REQ_OUT   (dma_req_tft),
    .READ_ACK_IN    (dma_ack_tft)
);

// Data width conversion
logic [TFT_WIDTH-1:0] data_tft;
logic req_tft, ack_tft;

assign data_tft    = dma_data_tft[TFT_WIDTH-1:0];
assign req_tft     = dma_req_tft;
assign dma_ack_tft = ack_tft;

// AHB DMA master
TFT_DMA #(
    .BASE_ADDR  (BASE_ADDR),
    .LENGTH     (HDISP * VDISP * TFT_WIDTH / 32)
) dma (
    .HCLK       (HCLK),
    .HRESET     (HRESET),
    .HADDR      (HADDR),
    .HBURST     (HBURST),
    .HTRANS     (HTRANS),
    .HWRITE     (HWRITE),
    .HWDATA     (HWDATA),
    .HRDATA     (HRDATA),
    .HREADY     (HREADY),
    .HRESP      (HRESP),

    .DATA_OUT   (dma_data_ahb),
    .REQ_OUT    (dma_req_ahb),
    .ACK_IN     (dma_ack_ahb),

    .VSYNC_IN   (vsync_ahb)
);

// TFT interface
TFT_IO #(
    .HSYNC      (HSYNC),
    .HBACK      (HBACK),
    .HDISP      (HDISP),
    .HFRONT     (HFRONT),
    .VSYNC      (VSYNC),
    .VBACK      (VBACK),
    .VDISP      (VDISP),
    .VFRONT     (VFRONT),
    .TFT_WIDTH  (TFT_WIDTH)
) io (
    .CLK            (CLK_TFT),
    .RESET_IN       (RESET_TFT),

    .DATA_IN        (data_tft),
    .REQ_IN         (req_tft),
    .ACK_OUT        (ack_tft),

    .UNDERFLOW_OUT  (UNDERFLOW_OUT),
    .VSYNC_OUT      (vsync_tft),

    .TFT_DCLK       (TFT_DCLK),
    .TFT_DISP       (TFT_DISP),
    .TFT_VSYNC      (TFT_VSYNC),
    .TFT_HSYNC      (TFT_HSYNC),
    .TFT_RGB        (TFT_RGB)
);

endmodule
