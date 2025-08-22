module NES_MAPPER #(
    parameter string BOOTROM_PRG,
    parameter string BOOTROM_CHR
) (
    input  wire         CLK,
    input  wire         RESET_IN,

    input  logic [15:0] CPU_ADDR_IN,
    input  logic        CPU_READ_ENABLE_IN,
    output logic [7:0]  CPU_READ_DATA_OUT,
    input  logic        CPU_WRITE_ENABLE_IN,
    input  logic [7:0]  CPU_WRITE_DATA_IN,

    input  logic [13:0] PPU_ADDR_IN,
    input  logic        PPU_READ_ENABLE_IN,
    output logic [7:0]  PPU_READ_DATA_OUT,
    input  logic        PPU_WRITE_ENABLE_IN,
    input  logic [7:0]  PPU_WRITE_DATA_IN
);

// Mapper 0

// CPU.PRG @ 0x8000 + 0x8000
logic [7:0] prg_ram_read_data;
assign prg_ram_sel = CPU_ADDR_IN >= 'h8000;
RAM_SP #(
    .WIDTH (8),
    .DEPTH ('h8000),
    .INIT  (BOOTROM_PRG)
) prg_ram (
    .CLK             (CLK),
    .RESET_IN        (RESET_IN),
    .ADDR_IN         (CPU_ADDR_IN[14:0]),
    .READ_ENABLE_IN  (prg_ram_sel & CPU_READ_ENABLE_IN),
    .READ_DATA_OUT   (prg_ram_read_data),
    .WRITE_ENABLE_IN (prg_ram_sel & CPU_WRITE_ENABLE_IN),
    .WRITE_DATA_IN   (CPU_WRITE_DATA_IN)
);

assign CPU_READ_DATA_OUT = prg_ram_read_data;

// PPU.CHR @ 0x0000 + 0x2000
logic [7:0] chr_ram_read_data;
assign chr_ram_sel = PPU_ADDR_IN < 'h2000;
RAM_SP #(
    .WIDTH (8),
    .DEPTH ('h2000),
    .INIT  (BOOTROM_CHR)
) chr_ram (
    .CLK             (CLK),
    .RESET_IN        (RESET_IN),
    .ADDR_IN         (PPU_ADDR_IN[12:0]),
    .READ_ENABLE_IN  (chr_ram_sel & PPU_READ_ENABLE_IN),
    .READ_DATA_OUT   (chr_ram_read_data),
    .WRITE_ENABLE_IN (chr_ram_sel & PPU_WRITE_ENABLE_IN),
    .WRITE_DATA_IN   (PPU_WRITE_DATA_IN)
);

// PPU.VRAM @ 0x2000 + 0x1000
logic [7:0] vram_read_data;
assign vram_sel = PPU_ADDR_IN >= 'h2000;
RAM_SP #(
    .WIDTH (8),
    .DEPTH ('h800)
) vram (
    .CLK             (CLK),
    .RESET_IN        (RESET_IN),
    .ADDR_IN         (PPU_ADDR_IN[10:0]),
    .READ_ENABLE_IN  (vram_sel & PPU_READ_ENABLE_IN),
    .READ_DATA_OUT   (vram_read_data),
    .WRITE_ENABLE_IN (vram_sel & PPU_WRITE_ENABLE_IN),
    .WRITE_DATA_IN   (PPU_WRITE_DATA_IN)
);

logic vram_out;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        vram_out <= 0;
    else if (PPU_READ_ENABLE_IN)
        vram_out <= vram_sel;

assign PPU_READ_DATA_OUT = vram_out ? vram_read_data : chr_ram_read_data;

endmodule
