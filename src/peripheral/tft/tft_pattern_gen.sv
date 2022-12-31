module TFT_PATTERN_GEN #(
    // FrameBuffer base address
    parameter logic [31:0] BASE_ADDR = 0,
    // Display area size
    parameter int WIDTH,
    parameter int HEIGHT,
    // Pixel bitwidth
    parameter int PIXEL_WIDTH
) (
    // AHB (fake) memory slave
    input  wire             HCLK,
    input  wire             HRESET,
    input  logic [31:0]     HADDR,
    input  AHB_PKG::burst_t HBURST,
    input  AHB_PKG::trans_t HTRANS,
    input  logic            HWRITE,
    input  logic [31:0]     HWDATA,
    output logic [31:0]     HRDATA,
    output logic            HREADY,
    output logic            HRESP
);

// Always ready
assign HREADY = 1;
assign HRESP  = 0;

logic start;
assign start = HADDR == BASE_ADDR;

logic req;
assign req = HTRANS != AHB_PKG::TRANS_IDLE && HTRANS != AHB_PKG::TRANS_BUSY;

always_ff @(posedge HCLK)
    HRDATA <= (HADDR - BASE_ADDR) >> 2;

endmodule
