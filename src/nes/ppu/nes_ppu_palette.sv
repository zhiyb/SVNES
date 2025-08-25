module NES_PPU_PALETTE (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        CLK_ENABLE_IN,

    // PPU data bus
    input  logic [13:0] PPU_ADDR_IN,
    input  logic        PPU_READ_ENABLE_IN,
    output logic [7:0]  PPU_READ_DATA_OUT,
    input  logic        PPU_WRITE_ENABLE_IN,
    input  logic [7:0]  PPU_WRITE_DATA_IN
);

typedef logic [5:0] clr_t;

typedef struct packed {
    clr_t clr0;
    clr_t [3:1] bg, sp;
} data_t;
data_t [3:0] data;

clr_t ppu_clr;
logic ppu_sp;
logic [1:0] ppu_palette;
logic [1:0] ppu_entry;

assign ppu_clr     = clr_t'(PPU_WRITE_DATA_IN);
assign ppu_sp      = PPU_ADDR_IN[4];
assign ppu_palette = PPU_ADDR_IN[3:2];
assign ppu_entry   = PPU_ADDR_IN[1:0];

always_ff @(posedge CLK) begin
    if (PPU_WRITE_ENABLE_IN) begin
        if (ppu_entry == 0)
            data[ppu_palette].clr0 <= ppu_clr;
        else if (ppu_sp)
            data[ppu_palette].sp[ppu_entry] <= ppu_clr;
        else
            data[ppu_palette].bg[ppu_entry] <= ppu_clr;
    end
end

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        PPU_READ_DATA_OUT <= 0;
    end else if (PPU_READ_ENABLE_IN) begin
        if (ppu_entry == 0)
            PPU_READ_DATA_OUT <= data[ppu_palette].clr0;
        else if (ppu_sp)
            PPU_READ_DATA_OUT <= data[ppu_palette].sp[ppu_entry];
        else
            PPU_READ_DATA_OUT <= data[ppu_palette].bg[ppu_entry];
    end
end

endmodule
