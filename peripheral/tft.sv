module TFT #(
    // Horizontal & vertical: Sync width, back porch, display, front porch
    parameter HSYNC, HBACK, HDISP, HFRONT,
    parameter VSYNC, VBACK, VDISP, VFRONT,
    // Pixel width
    parameter WIDTH = 24,

    // Derived
    parameter HN = $clog2(HBACK + HDISP + HFRONT),
    parameter VN = $clog2(VBACK + VDISP + VFRONT)
) (
    input wire  CLK,
    input logic RESET,
    input logic EN,

    // Upstream interface
    output logic             VBLANK,
    output logic             HBLANK,
    input  logic [WIDTH-1:0] COLOUR,

    // Hardware IO
    output wire              HW_DCLK,
    output logic             HW_DISP, HW_VSYNC, HW_HSYNC,
    output logic [WIDTH-1:0] HW_RGB
);

// Horizontal control
logic [HN-1:0] HCount;
logic HSync, HDisp, HEnd;
logic z1_HBlank, z1_HSync;

always_ff @(posedge CLK, negedge RESET)
    if (~RESET) begin
        HCount    <= 0;
        z1_HBlank <= 1;
        z1_HSync  <= 1;
    end else if (EN) begin
        if (HEnd)
            HCount <= 0;
        else
            HCount <= HCount + 1;
        z1_HBlank <= ~HDisp;
        z1_HSync  <= HSync;
    end

assign HSync  = HCount < HSYNC;
assign HDisp  = (HCount >= HBACK) & (HCount < HBACK + HDISP);
assign HEnd   = HCount == HBACK + HDISP + HFRONT - 1;
assign HBLANK = z1_HBlank;

// Vertical control
logic [VN-1:0] VCount;
logic VSync, VDisp, VEnd;
logic z1_VBlank, z1_VSync;

always_ff @(posedge CLK, negedge RESET)
    if (~RESET) begin
        VCount    <= 0;
        z1_VBlank <= 1;
        z1_VSync  <= 1;
    end else if (EN) begin
        if (VEnd &  HEnd)
            VCount <= 0;
        else if (HEnd)
            VCount <= VCount + 1;
        z1_VBlank <= ~VDisp;
        z1_VSync  <= VSync;
    end

assign VSync  = VCount < VSYNC;
assign VDisp  = (VCount >= VBACK) & (VCount < VBACK + VDISP);
assign VEnd   = VCount == VBACK + VDISP + VFRONT - 1;
assign VBLANK = z1_VBlank;

// Hardware IO
assign HW_DCLK = CLK;

always_ff @(posedge CLK, negedge RESET)
    if (~RESET)
        HW_DISP <= 0;
    else if (HW_DISP != EN)
        HW_DISP <= EN;

// Delay HW_HSYNC & HW_VSYNC to match HW_RGB output latency
always_ff @(posedge CLK, negedge RESET)
    if (~RESET) begin
        HW_VSYNC <= 0;
        HW_HSYNC <= 0;
    end else if (EN) begin
        HW_VSYNC <= z1_VSync;
        HW_HSYNC <= z1_HSync;
    end

always_ff @(posedge CLK)
    if (~HBLANK & ~VBLANK)
        HW_RGB <= COLOUR;

endmodule
