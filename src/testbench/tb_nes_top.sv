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

logic        nes_pixel_vblank;
logic        nes_pixel_valid;
logic [23:0] nes_pixel_rgb;

NES_TOP #(
    .BOOTROM_PRG ("output_files/prg_rom"),
    .BOOTROM_CHR ("output_files/chr_rom")
) nes (
    .CLK_SYS          (clk_sys),
    .RESET_SYS_IN     (reset_sys),
    .CLK_EMU          (clk_emu),
    .RESET_EMU_IN     (reset_emu),
    .VIDEO_MODE_OUT   (),
    .VIDEO_TOGGLE_IN  (video_toggle),
    .PIXEL_VBLANK_OUT (nes_pixel_vblank),
    .PIXEL_VALID_OUT  (nes_pixel_valid),
    .PIXEL_RGB_OUT    (nes_pixel_rgb),
    .BUTTON_IN        ('0)
);

// NES screen to framebuffer
NES_DMA #(
    .BASE_ADDR (32'h08800000),
    .H_STRIP   (800),
    .X_OFFSET  (128),
    .Y_OFFSET  (128)
) nes_dma (
    .CLK             (clk_emu),
    .RESET_IN        (reset_emu),
    .PIXEL_VBLANK_IN (nes_pixel_vblank),
    .PIXEL_VALID_IN  (nes_pixel_valid),
    .PIXEL_RGB_IN    (nes_pixel_rgb),

    .HCLK            (clk_sys),
    .HRESET          (reset_sys),
    .HADDR           (),
    .HBURST          (),
    .HSIZE           (),
    .HTRANS          (),
    .HWRITE          (),
    .HWDATA          (),
    .HRDATA          ('x),
    .HREADY          ('1),
    .HRESP           (AHB_PKG::RESP_OKAY)
);

initial begin
    forever begin
        #10ms;
        $display("Simulation time: %0g ms", $realtime / 1.0ms);
    end
end

initial
    #(150ms + 30ms) $finish(0);

endmodule
