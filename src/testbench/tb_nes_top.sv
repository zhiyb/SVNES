module TB_NES_TOP;

// 143MHz SYS clock
logic clk_sys;
logic reset_sys;
initial
begin
    clk_sys = 0;
    reset_sys = 0;
    reset_sys = 1;
    #1ns;
    reset_sys = 0;
    forever
        #(0.5/143.0 * 1us) clk_sys = ~clk_sys;
end

// 100MHz EMU clock
logic clk_emu;
logic reset_emu;
initial
begin
    clk_emu = 0;
    reset_emu = 0;
    reset_emu = 1;
    #1ns;
    reset_emu = 0;
    forever
        #(0.5/100.0 * 1us) clk_emu = ~clk_emu;
end

// 30MHz Video master clock
logic video_toggle;
initial
begin
    video_toggle = 0;
    forever
        #(1.0/30.0 * 1us) video_toggle = ~video_toggle;
end

NES_TOP #(
    .BOOTROM_PRG ("prg_rom"),
    .BOOTROM_CHR ("chr_rom")
) nes (
    .CLK_SYS         (clk_sys),
    .RESET_SYS_IN    (reset_sys),
    .CLK_EMU         (clk_emu),
    .RESET_EMU_IN    (reset_emu),
    .VIDEO_MODE_OUT  (),
    .VIDEO_TOGGLE_IN (video_toggle),
    .BUTTON_IN       ('0)
);

initial
    #12ms $finish(0);

endmodule
