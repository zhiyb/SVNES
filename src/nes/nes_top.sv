module NES_TOP #(
    parameter string BOOTROM
) (
    input  wire        CLK_SYS,
    input  wire        RESET_SYS_IN,

    input  wire        CLK_EMU,
    input  wire        RESET_EMU_IN,

    output logic [1:0] VIDEO_MODE_OUT,
    input  logic       VIDEO_TOGGLE_IN,

    input  logic [7:0] BUTTON_IN,
    output logic [7:0] DEBUG_OUT
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


// System bus
typedef logic [15:0] addr_t;
typedef logic [7:0]  data_t;
addr_t sys_addr;
data_t sys_read_data, sys_write_data;
logic  sys_read, sys_write;


// CPU and related peripherals
NES_CPU #(
    .BOOTROM (BOOTROM)
) cpu (
    .CLK              (CLK_EMU),
    .RESET_IN         (RESET_EMU_IN),
    .CLK_ENABLE_IN    (cpu_pulse),

    .INT_RESET_IN     ('0),
    .INT_NMI_IN       ('0),
    .INT_IRQ_IN       ('0),

    .ADDR_OUT         (sys_addr),
    .READ_ENABLE_OUT  (sys_read),
    .READ_DATA_IN     (sys_read_data),
    .WRITE_ENABLE_OUT (sys_write),
    .WRITE_DATA_OUT   (sys_write_data)
);


// TODO
assign sys_read_data = 0;

assign DEBUG_OUT = sys_addr[15:8] ^ sys_addr[7:0] ^ {6'b0, sys_read, sys_write};


// PPU memory map


endmodule
