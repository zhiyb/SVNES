module TFT_IO #(
    // Horizontal & vertical: sync width, back porch, display, front porch
    parameter HSYNC, HBACK, HDISP, HFRONT,
    parameter VSYNC, VBACK, VDISP, VFRONT,
    // Pixel RGB output width
    parameter TFT_WIDTH = 24,

    // Derived
    parameter HN = $clog2(HBACK + HDISP + HFRONT),
    parameter VN = $clog2(VBACK + VDISP + VFRONT)
) (
    input  wire CLK,
    input  wire RESET_IN,

    // Data input
    input  logic [TFT_WIDTH-1:0] DATA_IN,
    input  logic                 REQ_IN,
    output logic                 ACK_OUT,

    // Status report
    output logic UNDERFLOW_OUT,
    output logic VSYNC_OUT,

    // Hardware IO
    output wire  TFT_DCLK,
    output logic TFT_DISP, TFT_VSYNC, TFT_HSYNC,
    output logic [TFT_WIDTH-1:0] TFT_RGB
);

logic enable_tft;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        enable_tft <= 0;
    else
        enable_tft <= 1;

assign TFT_DCLK = CLK;
assign TFT_DISP = enable_tft;

// Horizontal counter
localparam HINIT = HBACK + HDISP + HFRONT - 1;
logic [HN-1:0] hcnt;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        hcnt <= 0;
    else if (hcnt != 0)
        hcnt <= hcnt - 1;
    else if (enable_tft)
        hcnt <= HINIT;

// Vertical counter
localparam VINIT = VBACK + VDISP + VFRONT - 1;
logic [VN-1:0] vcnt;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN) begin
        vcnt <= 0;
    end else if (hcnt == 0) begin
        if (vcnt != 0)
            vcnt <= vcnt - 1;
        else if (enable_tft)
            vcnt <= VINIT;
    end

logic hsync, vsync;

assign hsync = hcnt > HINIT - HSYNC;
assign vsync = vcnt > VINIT - VSYNC;

logic disp;
assign disp = hcnt > HINIT - HBACK - HDISP && hcnt <= HINIT - HBACK &&
              vcnt > VINIT - VBACK - VDISP && vcnt <= VINIT - VBACK;

// Flush FIFO data during VSYNC
assign ACK_OUT = VSYNC_OUT | disp;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        UNDERFLOW_OUT <= 0;
    else if (VSYNC_OUT)
        UNDERFLOW_OUT <= 0;
    else if (disp & ~REQ_IN)
        UNDERFLOW_OUT <= 1;

always_ff @(posedge CLK) begin
    TFT_HSYNC <= hsync;
    TFT_VSYNC <= vsync;
    TFT_RGB   <= DATA_IN;
end

assign VSYNC_OUT = TFT_VSYNC;

endmodule
