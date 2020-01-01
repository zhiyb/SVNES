// {{{ Clocks and reset control
module clk_reset (
    input logic CLOCK_50,
    output logic clkSYS, clkSDRAMIO, clkSDRAM, clkTFT, clkAudio, clkDebug,
    output logic clkMaster, clkPPU, clkCPU2,
    input logic [1:0] KEY,
    input logic [3:0] SW,
    output logic clk,
    input logic n_reset_mem,
    output logic n_reset, n_reset_ext,
    // Debug info scan chain
    input logic dbg_load, dbg_shift,
    input logic dbg_din,
    output logic dbg_dout
);

// Debug info scan
logic dbg_updated;
logic [7:0] dbg, dbg_out;
debug_scan dbg0 (.*);

// Reset control
always_ff @(posedge clkSYS)
begin
    n_reset_ext <= KEY[1];
    n_reset <= n_reset_ext & n_reset_mem;
end

// Clocks
logic clk10M, clk50M, clkSYS1;
assign clk50M = CLOCK_50;
assign clkAudio = clk10M;
assign clkDebug = clk50M;
pll pll0 (.inclk0(clk50M), .locked(),
    .c0(clkSDRAMIO), .c1(clkSDRAM), .c2(clk10M), .c3(clkTFT), .c4(clkSYS1));

// 1Hz counter
logic [23:0] cnt;
always_ff @(posedge clk10M)
    if (cnt == 0)
        cnt <= 10000000;
    else
        cnt <= cnt - 1;

always_ff @(posedge clk10M, negedge n_reset)
    if (~n_reset)
        dbg <= 0;
    else if (cnt == 0)
        dbg <= dbg + 1;

// System interface clock switch for debugging
`ifdef MODEL_TECH
assign clk = 0;
assign clkSYS = clkSYS1;
`else
always_ff @(posedge clk10M)
    if (cnt == 0 && ~KEY[1])
        clk <= ~clk;

logic sys[2];
assign sys[0] = clkSYS1;
assign sys[1] = clkSDRAM;
assign clkSYS = sys[clk];
`endif

// NES clocks
pll_ntsc pll1 (.areset(1'b0), .inclk0(clk50M), .locked(),
    .c0(clkMaster), .c1(clkPPU), .c2(clkCPU2));

endmodule
// }}}

module wrapper (
    // {{{ Inputs & outputs
    input logic CLOCK_50,
    input logic [1:0] KEY,
    input logic [3:0] SW,
    output logic [7:0] LED,
    
    output logic [12:0] DRAM_ADDR,
    output logic [1:0] DRAM_BA, DRAM_DQM,
    output logic DRAM_CKE, DRAM_CLK,
    output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
    inout wire [15:0] DRAM_DQ,
    
    inout wire I2C_SCLK, I2C_SDAT,
    
    output logic G_SENSOR_CS_N,
    input logic G_SENSOR_INT,
    
    output logic ADC_CS_N, ADC_SADDR, ADC_SCLK,
    input logic ADC_SDAT,
    
    inout wire [33:0] GPIO_0,
    input logic [1:0] GPIO_0_IN,
    inout wire [33:0] GPIO_1,
    input logic [1:0] GPIO_1_IN,
    inout wire [12:0] GPIO_2,
    input logic [2:0] GPIO_2_IN
    // }}}
);

// Debug info scan chain
logic dbg_load, dbg_shift;
logic dbg_d[8];

// Clocks and reset control
logic clkSYS, clkSDRAMIO, clkSDRAM, clkTFT, clkAudio, clkDebug;
logic clkMaster, clkPPU, clkCPU2;
logic clk;
logic n_reset, n_reset_ext, n_reset_mem;
clk_reset cr0 (.dbg_din(dbg_d[1]), .dbg_dout(dbg_d[0]), .*);

// {{{ Memory subsystem

localparam AN = 24, DN = 16, IN = 4, BURST = 8;

logic [AN - 1:0] arb_addr[IN];
logic [DN - 1:0] arb_data[IN];
logic arb_wr[IN];
logic [IN - 1:0] arb_req, arb_ack;

logic [DN - 1:0] arb_data_out;
logic [IN - 1:0] arb_valid;

logic [1:0] sdram_level;
logic sdram_empty, sdram_full;
sdram_shared #(AN, DN, IN, BURST) mem0 (.n_reset(n_reset_ext), .*);

// Memory access arbiter assignments
localparam tft = 0, cpu = 1, ppu = 2, disp = 3;

// TFT frame buffer
localparam TFT_BASE = 24'hfa0000, TFT_LS = 800;
logic [15:0] tft_fifo;
logic tft_wrreq, tft_rdreq;
logic tft_hblank, tft_vblank;
tft_fb #(AN, DN, BURST, TFT_BASE) tft_fb0 (clkSYS, clkTFT, n_reset,
    arb_addr[tft], arb_req[tft], arb_ack[tft],
    arb_data_out, arb_valid[tft],
    tft_fifo, tft_wrreq, tft_rdreq, tft_vblank);
assign arb_wr[tft] = 1'b0;
assign arb_data[tft] = 'bx;

// Display elements
// PPU frame buffer
logic [23:0] video_rgb;
logic video_vblank, video_hblank;
logic fb_empty, fb_full, test_fail;
// Debug processor frame buffer
logic [19:0] dbg_addr;
logic [15:0] dbg_data;
logic dbg_req;
logic dbg_empty, dbg_full;
display #(AN, DN, BURST, TFT_BASE, TFT_LS) disp0 (
    clkSYS, clkPPU, clkDebug, n_reset,
    // Memory interface
    arb_addr[disp], arb_data[disp],
    arb_req[disp], arb_wr[disp], arb_ack[disp],
    arb_data_out, arb_valid[disp],
    // PPU video
    video_rgb, video_vblank, video_hblank,
    // Debug processor
    dbg_addr, dbg_data, dbg_req,
    // Switches
    KEY, SW,
    // Debug info scan chain
    dbg_load, dbg_shift, dbg_d[2], dbg_d[1],
    // Status
    fb_empty, fb_full, dbg_empty, dbg_full, test_fail
);

// }}}

// {{{ NES system

// Main system
logic clkCPU, clkCPUn, clkRAM;
logic sys_reset;
wire sys_irq;
// CPU bus
logic [15:0] sys_addr;
wire [7:0] sys_data;
logic sys_rw;
wire sys_rdy;
// PPU bus
logic [13:0] ppu_addr;
wire [7:0] ppu_data;
logic ppu_rd, ppu_wr;
// Audio
logic [7:0] audio;
system sys0 (.dbg_din(dbg_d[3]), .dbg_dout(dbg_d[2]), .*);

// Mappers
// Memory interface - CPU
logic [23:0] mem_addr;
logic [15:0] mem_data;
logic mem_req, mem_wr;
logic mem_ack;
logic [15:0] mem_out;
logic mem_valid;
assign arb_addr[cpu] = mem_addr;
assign arb_data[cpu] = mem_data;
assign arb_req[cpu] = mem_req;
assign arb_wr[cpu] = mem_wr;
assign mem_ack = arb_ack[cpu];
assign mem_out = arb_data_out;
assign mem_valid = arb_valid[cpu];
// Memory interface - PPU
logic [23:0] mem_ppu_addr;
logic [15:0] mem_ppu_data;
logic mem_ppu_req, mem_ppu_wr;
logic mem_ppu_ack;
logic [15:0] mem_ppu_out;
logic mem_ppu_valid;
assign arb_addr[ppu] = mem_ppu_addr;
assign arb_data[ppu] = mem_ppu_data;
assign arb_req[ppu] = mem_ppu_req;
assign arb_wr[ppu] = mem_ppu_wr;
assign mem_ppu_ack = arb_ack[ppu];
assign mem_ppu_out = arb_data_out;
assign mem_ppu_valid = arb_valid[ppu];
mapper map0 (.*);

// }}}

// Debug processor
debug debug0 (clkDebug, n_reset,
    dbg_addr, dbg_data, dbg_req,
    dbg_load, dbg_shift, dbg_d[0], dbg_d[3]);

// {{{ Hardware controllers

// TFT controller
logic [5:0] tft_level;
logic tft_empty, tft_full;
`ifdef MODEL_TECH
tft #(10, '{1, 1, 256, 1}, 10, '{1, 1, 128, 1}) tft0
`else
//tft #(10, '{1, 40, 479, 1}, 10, '{1, 9, 271, 1}) tft0
tft #(10, '{1, 43, 799, 15}, 10, '{1, 20, 479, 6}) tft0
`endif
    (clkSYS, clkTFT, n_reset,
    // FIFO interface
    tft_fifo, tft_wrreq, tft_rdreq,
    // TFT signals
    tft_hblank, tft_vblank,
    // disp, de, dclk, vsync, hsync
    GPIO_0[30], , GPIO_0[29], GPIO_0[33], GPIO_0[31],
    // out
    {GPIO_0[7:0], GPIO_0[18:16], GPIO_0[14:13], GPIO_0[11:10], GPIO_0[8], GPIO_0[28], GPIO_0[26:21], GPIO_0[19]},
    // Status
    tft_level, tft_empty, tft_full);

logic tft_pwm;
assign GPIO_0[32] = tft_pwm;
assign tft_pwm = n_reset;

// Audio PWM
logic aout;
assign GPIO_1[25] = aout;
apu_pwm #(.N(8)) pwm0 (clkAudio, n_reset, audio, SW[0], aout);

// }}}

// Debugging LEDs
assign LED[7:0] = {clk, test_fail, dbg_full, dbg_empty,
    fb_full, tft_empty, sdram_full, sdram_empty};

endmodule
