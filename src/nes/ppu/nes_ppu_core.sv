module NES_PPU_CORE (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        CLK_ENABLE_IN,

    // Interrupts
    output logic        INT_VBLANK_OUT,

    // Pixel output
    output logic        PIXEL_VBLANK_OUT,
    output logic        PIXEL_VALID_OUT,
    output logic        PIXEL_SP_OUT,
    output logic [1:0]  PIXEL_PLT_OUT,
    output logic [1:0]  PIXEL_PTN_OUT,

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

typedef logic [13:0] ppu_addr_t;
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

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        ppu_ctrl <= 0;
    else if (cpu_write && reg_addr == PPU_CTRL)
        ppu_ctrl <= CPU_WRITE_DATA_IN;
end

ppu_addr_t bg_base_addr;
assign bg_base_addr = ppu_ctrl.bg_addr ? 'h1000 : 'h0000;

ppu_addr_t sp_base_addr;
assign sp_base_addr = ppu_ctrl.sp_addr ? 'h1000 : 'h0000;


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

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        ppu_mask <= 0;
    else if (cpu_write && reg_addr == PPU_MASK)
        ppu_mask <= CPU_WRITE_DATA_IN;
end

logic rdr_en;
assign rdr_en = ppu_mask.bg_en || ppu_mask.sp_en;

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

logic set_vblank, clr_vblank;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        ppu_status.vblank <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (set_vblank)
            ppu_status.vblank <= 1;
        if (clr_vblank)
            ppu_status.vblank <= 0;
        if (cpu_read && reg_addr == PPU_STATUS)
            ppu_status.vblank <= 0;
    end
end

assign INT_VBLANK_OUT = ppu_status.vblank;

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

// Renderer
logic [8:0] x, y;
logic skip;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        x <= 0;
        y <= 0;
        skip <= 0;
    end else if (CLK_ENABLE_IN) begin
        x <= x + 1;
        if (x == 340) begin
            x <= 0;
            y <= y + 1;
            if (y == 261)
                y <= 0;
        end
        if (set_vblank)
            skip <= ~skip;
        if (skip && x == 339 && y == 261) begin
            x <= 0;
            y <= 0;
        end
    end
end

logic vblank;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        vblank <= 0;
    else if (!rdr_en)
        vblank <= 1;
    else if (x == 340 && y == 239)
        vblank <= 1;
    else if (x == 340 && y == 260)
        vblank <= 0;
end

// The ppu_status.vblank flag sets at different times
assign set_vblank = x == 0 && y == 241;
assign clr_vblank = x == 0 && y == 261;

// VRAM address counter
struct packed {
    logic [2:0] y_fine;
    logic [1:0] nt;
    logic [4:0] y_coarse;
    logic [4:0] x_coarse;
} v, t;

logic [2:0] x_fine;

logic [13:0] rdr_addr;
logic [2:0] rdr_fetch;
logic rdr_read;

logic [2:0] sp_cnt;
logic sp_sel;

assign rdr_fetch = x[2:0];

u8_t rdr_nt;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        rdr_addr  <= 0;
        rdr_read  <= 0;
    end else if (CLK_ENABLE_IN) begin
        rdr_read <= !vblank && rdr_fetch[0] == 0;
        if (rdr_fetch / 2 == 0)     // NT fetch
            rdr_addr <= {2'h2, v.nt, v.y_coarse, v.x_coarse};
        if (rdr_fetch / 2 == 1)     // AT fetch
            rdr_addr <= {2'h2, v.nt, 4'hf, v.y_coarse[4:2], v.x_coarse[4:2]};
        if (!sp_sel) begin
            if (rdr_fetch / 2 == 2)
                rdr_addr <= bg_base_addr + rdr_nt * 16 + 0 + v.y_fine;
            if (rdr_fetch / 2 == 3)
                rdr_addr <= bg_base_addr + rdr_nt * 16 + 8 + v.y_fine;
        end else begin
            // TODO sprite
            if (rdr_fetch / 2 == 2)
                rdr_addr <= sp_base_addr + v.y_fine;
            if (rdr_fetch / 2 == 3)
                rdr_addr <= sp_base_addr + v.y_fine;
        end
    end
end

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        sp_cnt <= 0;
        sp_sel <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (x == 259)
            sp_sel <= 1;
        else if (x == 320)
            sp_sel <= 0;
    end
end

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        v <= 0;
        t <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (!vblank && !sp_sel && rdr_fetch == 7) begin
            v.x_coarse <= v.x_coarse + 1;
            if (x == 255) begin
                {v.y_coarse, v.y_fine} <= {v.y_coarse, v.y_fine} + 1;
                if (v.y_fine == 7 && v.y_coarse >= 29) begin
                    {v.y_coarse, v.y_fine} <= 0;
                    v.nt[1] <= ~v.nt[1];
                end
            end
        end
        if (!vblank && x == 256) begin
            v.x_coarse = t.x_coarse;
        end
        if (!vblank && y >= 261 && x >= 280 && x <= 304) begin
            {v.y_coarse, v.y_fine} = {t.y_coarse, t.y_fine};
        end
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

logic [2:0] rdr_fetch_pipe, rdr_fetch_read;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        {rdr_fetch_read, rdr_fetch_pipe} <= 0;
    else if (CLK_ENABLE_IN)
        {rdr_fetch_read, rdr_fetch_pipe} <= {rdr_fetch_pipe, rdr_fetch};
end

logic [1:0] rdr_at;
logic [15:0] rdr_bg_ptn;
logic rdr_latch;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        rdr_nt <= 0;
        rdr_at <= 0;
        rdr_bg_ptn <= 0;
        rdr_latch <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (rdr_fetch_read == 1)
            rdr_nt <= PPU_READ_DATA_IN;
        if (rdr_fetch_read == 3)
            rdr_at <= PPU_READ_DATA_IN >> {y[4], x[4], 1'b0};
        if (rdr_fetch_read == 5)
            rdr_bg_ptn[7:0] <= PPU_READ_DATA_IN;
        if (rdr_fetch_read == 7)
            rdr_bg_ptn[15:8] <= PPU_READ_DATA_IN;
        rdr_latch <= 0;
        if (rdr_fetch_read == 7)
            rdr_latch <= ~sp_sel;
    end
end

logic rdr_valid;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        rdr_valid <= 0;
    else if (y < 240)
        rdr_valid <= x < 320;
end

// Renderer
logic [31:0] shift_at, shift_bg;
logic [3:0] shift_cnt;
logic shift_valid;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        shift_at <= 0;
        shift_bg <= 0;
        shift_cnt <= 0;
        shift_valid <= 1;
    end else if (CLK_ENABLE_IN) begin
        if (rdr_latch) begin
            int i;
            for (i = 0; i < 8; i++) begin
                shift_at[i * 2 +: 2] <= rdr_at;
                shift_bg[i * 2 + 0] <= rdr_bg_ptn[i + 0];
                shift_bg[i * 2 + 1] <= rdr_bg_ptn[i + 8];
            end
            shift_cnt <= 8;
            shift_valid <= rdr_valid;
        end else if (shift_cnt != 0) begin
            shift_at[31:2] <= shift_at[29:0];
            shift_bg[31:2] <= shift_bg[29:0];
            shift_cnt <= shift_cnt - 1;
        end
    end
end

logic [1:0] pixel_ptn, pixel_at;
logic pixel_sp;
logic pixel_out;
assign pixel_ptn = shift_bg[16 + (7 - x_fine) * 2 +: 2];    // TODO
assign pixel_at = shift_at[16 + (7 - x_fine) * 2 +: 2];
assign pixel_sp = 0;
assign pixel_out = shift_valid && shift_cnt != 0;

assign PIXEL_VBLANK_OUT = vblank;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        PIXEL_VALID_OUT <= 0;
        PIXEL_SP_OUT <= 0;
        PIXEL_PLT_OUT <= 0;
        PIXEL_PTN_OUT <= 0;
    end else if (CLK_ENABLE_IN) begin
        PIXEL_VALID_OUT <= pixel_out;
        if (pixel_out) begin
            PIXEL_SP_OUT <= pixel_sp;
            PIXEL_PLT_OUT <= pixel_at;
            PIXEL_PTN_OUT <= pixel_ptn;
        end
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
        if (rdr_read) begin
            PPU_ADDR_OUT         <= rdr_addr;
            PPU_READ_ENABLE_OUT  <= 1;
        end else if (cpu_write && reg_addr == PPU_DATA) begin
            PPU_WRITE_ENABLE_OUT <= 1;
            PPU_WRITE_DATA_OUT   <= CPU_WRITE_DATA_IN;
        end else if (cpu_read && reg_addr == PPU_DATA) begin
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
