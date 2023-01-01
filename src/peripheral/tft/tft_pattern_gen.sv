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

logic req;
assign req = HTRANS != AHB_PKG::TRANS_IDLE && HTRANS != AHB_PKG::TRANS_BUSY;

logic start;
assign start = HADDR == BASE_ADDR;

// Stall for 1 cycle at frame start
always_ff @(posedge HCLK)
    if (req & start)
        HREADY <= 0;
    else
        HREADY <= 1;

assign HRESP  = 0;

// X and Y counters
logic [15:0] x;
logic [15:0] y;

always_ff @(posedge HCLK)
    if (req & start)
        x <= 0;
    else if (req)
        x <= x == WIDTH - 1 ? 0 : x + 1;

always_ff @(posedge HCLK)
    if (req & start)
        y <= 0;
    else if (req)
        y <= x == WIDTH - 1 ? y + 1 : y;

logic [31:0] c;
localparam LINE = 2;
always_comb begin
    c = {{8{x[0] ^ y[0]}}, y[0 +: 8], x[0 +: 8]};
    if (x == 0)
        c = 'hff0000;
    else if (x == WIDTH - 1)
        c = 'h00ffff;
    else if (y == 0)
        c = 'h00ff00;
    else if (y == HEIGHT - 1)
        c = 'hff00ff;
    if (x >= WIDTH  / 2 - LINE && x < WIDTH      / 2 + LINE &&
        y >= HEIGHT / 4 - LINE && y < HEIGHT * 3 / 4 + LINE)
        c = {24{x[1] ^ y[1]}};
    if (x >= WIDTH  / 4 - LINE && x < WIDTH  * 3 / 4 + LINE &&
        y >= HEIGHT / 2 - LINE && y < HEIGHT     / 2 + LINE)
        c = {24{x[1] ^ y[1]}};
end

always_ff @(posedge HCLK)
    HRDATA <= c;

endmodule
