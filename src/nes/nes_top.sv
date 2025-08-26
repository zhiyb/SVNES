module NES_TOP #(
    parameter string BOOTROM_PRG,
    parameter string BOOTROM_CHR
) (
    input  wire         CLK_SYS,
    input  wire         RESET_SYS_IN,

    input  wire         CLK_EMU,
    input  wire         RESET_EMU_IN,

    output logic [1:0]  VIDEO_MODE_OUT,
    input  logic        VIDEO_TOGGLE_IN,

    // Pixel output
    output logic        PIXEL_VBLANK_OUT,
    output logic        PIXEL_VALID_OUT,
    output logic [23:0] PIXEL_RGB_OUT,

    input  logic [7:0]  BUTTON_IN,

    output logic        DEBUG_VALID_OUT,
    output logic [7:0]  DEBUG_OUT
);

typedef enum logic [1:0] {
    VIDEO_MODE_NTSC = 2'h0,
    VIDEO_MODE_PAL  = 2'h1
} video_mode_t;

assign VIDEO_MODE_OUT = VIDEO_MODE_NTSC;

// Master clock, CPU and PPU clock pulses
logic prev_video_toggle, master_pulse, cpu_pulse, ppu_pulse;
logic [3:0] cpu_pulse_cnt;
logic [2:0] ppu_pulse_cnt;
always_ff @(posedge CLK_EMU, posedge RESET_EMU_IN) begin
    if (RESET_EMU_IN) begin
        prev_video_toggle <= 0;
        master_pulse      <= 0;
        cpu_pulse_cnt     <= 0;
        cpu_pulse         <= 0;
        ppu_pulse_cnt     <= 0;
        ppu_pulse         <= 0;
    end else begin
        prev_video_toggle <= VIDEO_TOGGLE_IN;
        if (VIDEO_TOGGLE_IN ^ prev_video_toggle) begin
            master_pulse <= 1;

            if (cpu_pulse_cnt == 0) begin
                cpu_pulse_cnt <= VIDEO_MODE_OUT == VIDEO_MODE_NTSC ? 12 - 1 :
                                 VIDEO_MODE_OUT == VIDEO_MODE_PAL  ? 16 - 1 : 0;
            end else begin
                cpu_pulse_cnt <= cpu_pulse_cnt - 1;
            end
            cpu_pulse <= cpu_pulse_cnt == 0;

            if (ppu_pulse_cnt == 0) begin
                ppu_pulse_cnt <= VIDEO_MODE_OUT == VIDEO_MODE_NTSC ? 4 - 1 :
                                 VIDEO_MODE_OUT == VIDEO_MODE_PAL  ? 5 - 1 : 0;
            end else begin
                ppu_pulse_cnt <= ppu_pulse_cnt - 1;
            end
            ppu_pulse <= ppu_pulse_cnt == 0;

        end else begin
            master_pulse <= 0;
            cpu_pulse    <= 0;
            ppu_pulse    <= 0;
        end
    end
end


// CPU bus
typedef logic [15:0] cpu_addr_t;
typedef logic [7:0]  data_t;
cpu_addr_t cpu_addr;
data_t cpu_read_data, cpu_write_data;
logic cpu_read, cpu_write;

// CPU and related peripherals
NES_CPU cpu (
    .CLK              (CLK_EMU),
    .RESET_IN         (RESET_EMU_IN),
    .CLK_ENABLE_IN    (cpu_pulse),

    .INT_RESET_IN     ('0),
    .INT_NMI_IN       ('0),
    .INT_IRQ_IN       ('0),

    .ADDR_OUT         (cpu_addr),
    .READ_ENABLE_OUT  (cpu_read),
    .READ_DATA_IN     (cpu_read_data),
    .WRITE_ENABLE_OUT (cpu_write),
    .WRITE_DATA_OUT   (cpu_write_data),

    .DEBUG_VALID_OUT  (DEBUG_VALID_OUT),
    .DEBUG_OUT        (DEBUG_OUT)
);


// PPU bus
typedef logic [13:0] ppu_addr_t;
ppu_addr_t ppu_addr;
data_t ppu_read_data, ppu_write_data;
logic ppu_read, ppu_write;

// PPU
data_t ppu_cpu_read_data;

logic ppu_cpu_sel;
assign ppu_cpu_sel = cpu_addr >= 'h2000 && cpu_addr < 'h4000;

logic ppu_cpu_read_out;
always_ff @(posedge CLK_EMU, posedge RESET_EMU_IN)
    if (RESET_EMU_IN)
        ppu_cpu_read_out <= 0;
    else if (cpu_read)
        ppu_cpu_read_out <= ppu_cpu_sel;

`ifdef SIMULATIONx
NES_PPU_MODEL ppu (
`else
NES_PPU ppu (
`endif
    .CLK                  (CLK_EMU),
    .RESET_IN             (RESET_EMU_IN),
    .CLK_ENABLE_IN        (ppu_pulse),

    .INT_VBLANK_OUT       (),

    .PIXEL_VBLANK_OUT     (PIXEL_VBLANK_OUT),
    .PIXEL_VALID_OUT      (PIXEL_VALID_OUT),
    .PIXEL_RGB_OUT        (PIXEL_RGB_OUT),

    .CPU_ADDR_IN          (cpu_addr),
    .CPU_READ_ENABLE_IN   (ppu_cpu_sel & cpu_read),
    .CPU_READ_DATA_OUT    (ppu_cpu_read_data),
    .CPU_WRITE_ENABLE_IN  (ppu_cpu_sel & cpu_write),
    .CPU_WRITE_DATA_IN    (cpu_write_data),

    .PPU_ADDR_OUT         (ppu_addr),
    .PPU_READ_ENABLE_OUT  (ppu_read),
    .PPU_READ_DATA_IN     (ppu_read_data),
    .PPU_WRITE_ENABLE_OUT (ppu_write),
    .PPU_WRITE_DATA_OUT   (ppu_write_data)
);


// Mapper
data_t mapper_cpu_read_data;

logic mapper_cpu_sel;
assign mapper_cpu_sel = cpu_addr >= 'h4020;

NES_MAPPER #(
    .BOOTROM_PRG (BOOTROM_PRG),
    .BOOTROM_CHR (BOOTROM_CHR)
) mapper (
    .CLK                 (CLK_EMU),
    .RESET_IN            (RESET_EMU_IN),

    .CPU_ADDR_IN         (cpu_addr),
    .CPU_READ_ENABLE_IN  (mapper_cpu_sel & cpu_read),
    .CPU_READ_DATA_OUT   (mapper_cpu_read_data),
    .CPU_WRITE_ENABLE_IN (mapper_cpu_sel & cpu_write),
    .CPU_WRITE_DATA_IN   (cpu_write_data),

    .PPU_ADDR_IN         (ppu_addr),
    .PPU_READ_ENABLE_IN  (ppu_read),
    .PPU_READ_DATA_OUT   (ppu_read_data),
    .PPU_WRITE_ENABLE_IN (ppu_write),
    .PPU_WRITE_DATA_IN   (ppu_write_data)
);


// Read data mux
always_comb begin
    cpu_read_data = mapper_cpu_read_data;
    if (ppu_cpu_read_out)
        cpu_read_data = ppu_cpu_read_data;
end


// To keep synthesis not optimising away everything
// assign DEBUG_OUT = cpu_addr[15:8] ^ cpu_addr[7:0] ^ {6'b0, cpu_read, cpu_write};

endmodule
