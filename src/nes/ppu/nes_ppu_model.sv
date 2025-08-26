module NES_PPU_MODEL (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        CLK_ENABLE_IN,

    // Interrupts
    output logic        INT_VBLANK_OUT,

    // Pixel output
    output logic        PIXEL_VBLANK_OUT,
    output logic        PIXEL_VALID_OUT,
    output logic [23:0] PIXEL_RGB_OUT,

    // CPU register bus
    input  logic [15:0] CPU_ADDR_IN,
    input  logic        CPU_READ_ENABLE_IN,
    output logic [7:0]  CPU_READ_DATA_OUT,
    input  logic        CPU_WRITE_ENABLE_IN,
    input  logic [7:0]  CPU_WRITE_DATA_IN,

    // PPU data bus
    output logic [13:0] PPU_ADDR_OUT,
    output logic        PPU_READ_ENABLE_OUT,
    input  logic [7:0]  PPU_READ_DATA_IN,
    output logic        PPU_WRITE_ENABLE_OUT,
    output logic [7:0]  PPU_WRITE_DATA_OUT
);

assign INT_VBLANK_OUT = '0;

assign PIXEL_VBLANK_OUT = '0;
assign PIXEL_VALID_OUT = '0;
assign PIXEL_RGB_OUT = '0;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        CPU_READ_DATA_OUT <= 0;
    else if (CPU_READ_ENABLE_IN)
        CPU_READ_DATA_OUT <= ~CPU_READ_DATA_OUT;

assign PPU_ADDR_OUT = '0;
assign PPU_READ_ENABLE_OUT = '0;
assign PPU_WRITE_ENABLE_OUT = '0;
assign PPU_WRITE_DATA_OUT = '0;

endmodule
