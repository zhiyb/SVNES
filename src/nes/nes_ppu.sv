module NES_PPU (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        CLK_ENABLE_IN,

    // Interrupts

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

typedef logic [15:0] u16_t;
typedef logic [7:0] u8_t;

typedef enum {
    PPU_CTRL   = 0,
    PPU_MASK   = 1,
    PPU_STATUS = 2,
    OAM_ADDR   = 3,
    OAM_DATA   = 4,
    PPU_SCROLL = 5,
    PPU_ADDR   = 6,
    PPU_DATA   = 7
} reg_t;

logic [2:0] reg_addr;
assign reg_addr = CPU_ADDR_IN[2:0];

// PPU_STATUS
struct packed {
    logic vblank;
    logic sp0_hit;
    logic sp_ovf;
    logic [4:0] id;
} ppu_status;

assign ppu_status.id = 0;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        CPU_READ_DATA_OUT <= 0;
    end else if (CPU_READ_ENABLE_IN) begin
        if (reg_addr == PPU_STATUS)
            CPU_READ_DATA_OUT <= ppu_status;
    end
end

// TODO
assign PPU_READ_ENABLE_OUT = 0;
assign PPU_WRITE_ENABLE_OUT = 0;
assign PPU_WRITE_DATA_OUT = 0;

assign ppu_status.sp_ovf = 0;
assign ppu_status.sp0_hit = 0;

logic [7:0] vcnt;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        vcnt <= 0;
        ppu_status.vblank <= 0;
    end else begin
        if (CLK_ENABLE_IN) begin
            vcnt <= vcnt + 1;
            if (vcnt == 0)
                ppu_status.vblank <= 1;
        end
        if (CPU_READ_ENABLE_IN && reg_addr == PPU_STATUS)
            ppu_status.vblank <= 0;
    end
end

endmodule
