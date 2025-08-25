module NES_PPU (
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

typedef logic [7:0] u8_t;

// Rendering logic
u8_t ppu_read_data;
logic ppu_read_enable, ppu_write_enable;

logic       pixel_valid;
logic       pixel_sp;
logic [1:0] pixel_plt;
logic [1:0] pixel_ptn;

NES_PPU_CORE core (
    .CLK                  (CLK),
    .RESET_IN             (RESET_IN),
    .CLK_ENABLE_IN        (CLK_ENABLE_IN),

    .INT_VBLANK_OUT       (INT_VBLANK_OUT),

    .PIXEL_VBLANK_OUT     (PIXEL_VBLANK_OUT),
    .PIXEL_VALID_OUT      (pixel_valid),
    .PIXEL_SP_OUT         (pixel_sp),
    .PIXEL_PLT_OUT        (pixel_plt),
    .PIXEL_PTN_OUT        (pixel_ptn),

    .CPU_ADDR_IN          (CPU_ADDR_IN),
    .CPU_READ_ENABLE_IN   (CPU_READ_ENABLE_IN),
    .CPU_READ_DATA_OUT    (CPU_READ_DATA_OUT),
    .CPU_WRITE_ENABLE_IN  (CPU_WRITE_ENABLE_IN),
    .CPU_WRITE_DATA_IN    (CPU_WRITE_DATA_IN),

    .PPU_ADDR_OUT         (PPU_ADDR_OUT),
    .PPU_READ_ENABLE_OUT  (ppu_read_enable),
    .PPU_READ_DATA_IN     (ppu_read_data),
    .PPU_WRITE_ENABLE_OUT (ppu_write_enable),
    .PPU_WRITE_DATA_OUT   (PPU_WRITE_DATA_OUT)
);

// Palette
logic palette_sel;
assign palette_sel = PPU_ADDR_OUT >= 'h3f00;

logic palette_read_out;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        palette_read_out <= 0;
    else
        palette_read_out <= palette_sel;

u8_t palette_read_data;

logic pixel_plt_valid;
logic [5:0] pixel_plt_clr;

NES_PPU_PALETTE palette (
    .CLK                 (CLK),
    .RESET_IN            (RESET_IN),
    .CLK_ENABLE_IN       (CLK_ENABLE_IN),

    .PIXEL_VALID_IN      (pixel_valid),
    .PIXEL_SP_IN         (pixel_sp),
    .PIXEL_PLT_IN        (pixel_plt),
    .PIXEL_PTN_IN        (pixel_ptn),

    .PIXEL_VALID_OUT     (pixel_plt_valid),
    .PIXEL_CLR_OUT       (pixel_plt_clr),

    .PPU_ADDR_IN         (PPU_ADDR_OUT),
    .PPU_READ_ENABLE_IN  (ppu_read_enable & palette_sel),
    .PPU_READ_DATA_OUT   (palette_read_data),
    .PPU_WRITE_ENABLE_IN (ppu_write_enable & palette_sel),
    .PPU_WRITE_DATA_IN   (PPU_WRITE_DATA_OUT)
);

NES_PPU_RGB rgb (
    .CLK             (CLK),
    .RESET_IN        (RESET_IN),
    .PIXEL_VALID_IN  (pixel_plt_valid),
    .PIXEL_CLR_IN    (pixel_plt_clr),
    .PIXEL_VALID_OUT (PIXEL_VALID_OUT),
    .PIXEL_RGB_OUT   (PIXEL_RGB_OUT)
);

// External mapper
logic mapper_sel;
assign mapper_sel = !palette_sel;
assign PPU_READ_ENABLE_OUT  = ppu_read_enable;
assign PPU_WRITE_ENABLE_OUT = ppu_write_enable & mapper_sel;

// Read data mux
always_comb begin
    ppu_read_data = PPU_READ_DATA_IN;
    if (palette_read_out)
        ppu_read_data = palette_read_data;
end

endmodule
