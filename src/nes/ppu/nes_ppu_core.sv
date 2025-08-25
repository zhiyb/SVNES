module NES_PPU_CORE (
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

// Register CPU access requests until next PPU clock cycle
logic [2:0] reg_addr;
logic cpu_read_req, cpu_write_req;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        reg_addr      <= 0;
        cpu_read_req  <= 0;
        cpu_write_req <= 0;
    end else begin
        if (CPU_READ_ENABLE_IN || CPU_WRITE_ENABLE_IN)
            reg_addr      <= CPU_ADDR_IN[2:0];
        if (CPU_READ_ENABLE_IN)
            cpu_read_req  <= 1;
        else if (CLK_ENABLE_IN)
            cpu_read_req  <= 0;
        if (CPU_WRITE_ENABLE_IN)
            cpu_write_req <= 1;
        else if (CLK_ENABLE_IN)
            cpu_write_req <= 0;
    end
end

logic cpu_read, cpu_write;
assign cpu_read = CLK_ENABLE_IN & cpu_read_req;
assign cpu_write = CLK_ENABLE_IN & cpu_write_req;

// PPU registers
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

// 0x2000 PPU_CTRL
struct packed {
    logic vblank_nmi_en;
    logic ppu_ext_out;
    logic sprite_size;
    logic bg_addr;          // [0x0000, 0x1000]
    logic sp_addr;          // [0x0000, 0x1000]
    logic cpu_vram_dir;     // [horizontal, vertical]
    logic [1:0] nt_addr;    // [0x2000, 0x2400, 0x2800, 0x2c00]
} ppu_ctrl;

// TODO
assign ppu_ctrl = 0;

// 0x2001 PPU_MASK
struct packed {
    logic emp_blue;
    logic emp_green;
    logic emp_red;
    logic sp_en;
    logic bg_en;
    logic sp_left_en;
    logic bg_left_en;
    logic gs_en;
} ppu_mask;

// TODO
assign ppu_mask = 0;

// 0x2002 PPU_STATUS
struct packed {
    logic vblank;
    logic sp0_hit;
    logic sp_ovf;
    logic [4:0] id;
} ppu_status;

// TODO
assign ppu_status.id = 0;
assign ppu_status.sp_ovf = 0;
assign ppu_status.sp0_hit = 0;

logic [7:0] vcnt;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        vcnt <= 0;
        ppu_status.vblank <= 0;
    end else if (CLK_ENABLE_IN) begin
        vcnt <= vcnt + 1;
        if (vcnt == 0)
            ppu_status.vblank <= 1;
        if (cpu_read && reg_addr == PPU_STATUS)
            ppu_status.vblank <= 0;
    end
end

// 0x2003 OAM_ADDR, 0x2004 OAM_DATA
u8_t oam_addr;
u8_t oam_data;

// TODO
assign oam_addr = 0;
assign oam_data = 0;

// Word select counter
logic w;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        w <= 0;
    else if (cpu_read && reg_addr == PPU_STATUS)
        w <= 0;
    else if (cpu_write && reg_addr == PPU_SCROLL)
        w <= ~w;
    else if (cpu_write && reg_addr == PPU_ADDR)
        w <= ~w;
end

// VRAM address counter
struct packed {
    logic [2:0] y_fine;
    logic [1:0] nt;
    logic [4:0] y_coarse;
    logic [4:0] x_coarse;
} v, t;

logic [2:0] x_fine;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        v <= 0;
        t <= 0;
    end else begin
        if (cpu_write) begin
            if (reg_addr == PPU_CTRL)
                t.nt <= CPU_WRITE_DATA_IN[1:0];
            if (reg_addr == PPU_SCROLL && w == 0) begin
                t.x_coarse <= CPU_WRITE_DATA_IN[7:3];
                x_fine <= CPU_WRITE_DATA_IN[2:0];
            end
            if (reg_addr == PPU_SCROLL && w == 1) begin
                t.y_coarse <= CPU_WRITE_DATA_IN[7:3];
                t.y_fine <= CPU_WRITE_DATA_IN[2:0];
            end
            if (reg_addr == PPU_ADDR && w == 0)
                t[14:8] <= {1'b0, CPU_WRITE_DATA_IN[5:0]};
            if (reg_addr == PPU_ADDR && w == 1) begin
                t[7:0] <= CPU_WRITE_DATA_IN;
                v <= t;
                v[7:0] <= CPU_WRITE_DATA_IN;
            end
        end
        if ((cpu_write || cpu_read) && reg_addr == PPU_DATA)
            v <= v + (ppu_ctrl.cpu_vram_dir ? 32 : 1);
    end
end

// 0x2006 PPU_ADDR, 0x2007 PPU_DATA
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        PPU_ADDR_OUT         <= 0;
        PPU_READ_ENABLE_OUT  <= 0;
        PPU_WRITE_ENABLE_OUT <= 0;
        PPU_WRITE_DATA_OUT   <= 0;
    end else if (CLK_ENABLE_IN) begin
        PPU_ADDR_OUT <= v;
        if (cpu_write && reg_addr == PPU_DATA) begin
            PPU_WRITE_ENABLE_OUT <= 1;
            PPU_WRITE_DATA_OUT   <= CPU_WRITE_DATA_IN;
        end else begin
            PPU_READ_ENABLE_OUT  <= 1;
        end
    end else begin
        PPU_READ_ENABLE_OUT  <= 0;
        PPU_WRITE_ENABLE_OUT <= 0;
    end
end

// CPU read data
u8_t [7:0] regs;
always_comb begin
    regs = {8{CPU_READ_DATA_OUT}};
    // regs[0] = ppu_ctrl;
    // regs[1] = ppu_mask;
    regs[2] = ppu_status;
    // regs[3] = oam_addr;
    regs[4] = oam_data;
    // regs[5] = ppu_scroll;
    // regs[6] = ppu_addr;
    // regs[7] = ppu_data;
end

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        CPU_READ_DATA_OUT <= 0;
    else if (cpu_read)
        CPU_READ_DATA_OUT <= regs[reg_addr];
    else if (CLK_ENABLE_IN && reg_addr == PPU_DATA)
        CPU_READ_DATA_OUT <= PPU_READ_DATA_IN;
end

`ifdef SIMULATION
// Debug information
struct packed {
    reg_t reg_addr;
} debug;

always_ff @(posedge CLK) begin
    if (CPU_READ_ENABLE_IN || CPU_WRITE_ENABLE_IN)
        debug.reg_addr <= reg_t'(CPU_ADDR_IN[2:0]);
end
`endif

endmodule
