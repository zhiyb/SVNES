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
    output AHB_PKG::addr_t  HADDR,
    output AHB_PKG::burst_t HBURST,
    output AHB_PKG::size_t  HSIZE,
    output AHB_PKG::trans_t HTRANS,
    output logic            HWRITE,
    output AHB_PKG::data_t  HWDATA,
    input  AHB_PKG::data_t  HRDATA,
    input  logic            HREADY,
    input  AHB_PKG::resp_t  HRESP,

    // Hardware IO
    output wire  TFT_DCLK,
    output logic TFT_DISP, TFT_VSYNC, TFT_HSYNC,
    output logic [TFT_WIDTH-1:0] TFT_RGB
);

`define USE_RGB565 // SDRAM too slow for RGB888

// AHB CDC
logic vsync_ahb, vsync_tft;
CDC_ASYNC tp_cdc (
    .CLK        (HCLK),
    .RESET_IN   (HRESET),
    .DATA_IN    (vsync_tft),
    .DATA_OUT   (vsync_ahb)
);

// AHB DMA master
logic [31:0] dma_data;
logic dma_req, dma_ack;

TFT_DMA #(
    .WIDTH      (HDISP),
    .HEIGHT     (VDISP),
`ifdef USE_RGB565
    .BPP        (16),
`else
    .BPP        (32),
`endif
    .BASE_ADDR  (BASE_ADDR)
) dma (
    .HCLK       (HCLK),
    .HRESET     (HRESET),
    .HADDR      (HADDR),
    .HBURST     (HBURST),
    .HSIZE      (HSIZE),
    .HTRANS     (HTRANS),
    .HWRITE     (HWRITE),
    .HWDATA     (HWDATA),
    .HRDATA     (HRDATA),
    .HREADY     (HREADY),
    .HRESP      (HRESP),

    .DATA_OUT   (dma_data),
    .REQ_OUT    (dma_req),
    .ACK_IN     (dma_ack),

    .VSYNC_IN   (vsync_ahb)
);

logic [31:0] fifo_data;
logic fifo_req, fifo_ack;

FIFO_ASYNC #(
    .WIDTH  (32)
) fifo (
    .WRITE_CLK      (HCLK),
    .WRITE_RESET_IN (HRESET),
    .WRITE_DATA_IN  (dma_data),
    .WRITE_REQ_IN   (dma_req),
    .WRITE_ACK_OUT  (dma_ack),

    .READ_CLK       (CLK_TFT),
    .READ_RESET_IN  (RESET_TFT),
    .READ_DATA_OUT  (fifo_data),
    .READ_REQ_OUT   (fifo_req),
    .READ_ACK_IN    (fifo_ack)
);

// Data width conversion, RGB mapping
logic [TFT_WIDTH-1:0] data_tft;
logic req_tft, ack_tft;

`ifdef USE_RGB565
TFT_MAPPING #(
    .TFT_WIDTH  (TFT_WIDTH)
) map (
    .CLK        (CLK_TFT),
    .RESET_IN   (RESET_TFT),

    .DATA_IN    (fifo_data),
    .REQ_IN     (fifo_req),
    .ACK_OUT    (fifo_ack),

    .DATA_OUT   (data_tft),
    .REQ_OUT    (req_tft),
    .ACK_IN     (ack_tft)
);
`else
assign data_tft = fifo_data;
assign req_tft = fifo_req;
assign dma_ack_tft = fifo_ack;
`endif

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
