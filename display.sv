module display #(parameter AN, DN, BURST, TFT_BASE, TFT_LS) (
	input logic clkSYS, clkPPU, clkDebug, n_reset,

	// Memory interface
	output logic [AN - 1:0] addr,
	output logic [DN - 1:0] data,
	output logic req, wr,
	input logic ack,

	input logic [15:0] mem,
	input logic valid,

	// PPU video
	input logic [23:0] video_rgb,
	input logic video_vblank, video_hblank,

	// Debug processor
	input logic [19:0] dbg_addr,
	input logic [15:0] dbg_data,
	input logic dbg_req,

	// Switches
	input logic [1:0] KEY,
	input logic [3:0] SW,

	// Status
	output logic fb_empty, fb_full,
	output logic dbg_empty, dbg_full,
	output logic test_fail
);

localparam IN = 4;
localparam PPU_X = 120, PPU_Y = 120, PPU_W = 256, PPU_H = 240, MARGIN = 8;

// Memory access arbitration
logic [AN - 1:0] arb_addr[IN];
logic [DN - 1:0] arb_data[IN];
logic arb_wr[IN];
logic [IN - 1:0] arb_req;
logic [IN - 1:0] arb_ack;

localparam ppu = 0, dbg = 1, rect = 2, test = 3;

// Access request buffering
logic [AN - 1:0] in_addr[IN];
logic [DN - 1:0] in_data[IN];
logic in_wr[IN];
logic [IN - 1:0] in_req;
logic [IN - 1:0] in_ack;
sdram_shared_buf #(AN, DN, IN) buf0 (clkSYS, n_reset,
	arb_addr, arb_data, , arb_wr, arb_req, arb_ack,
	in_addr, in_data, , in_wr, in_req, in_ack);

// Memory access arbiter
sdram_shared_arbiter #(AN, DN, IN) arb0 (clkSYS, n_reset,
	in_addr, in_data, in_wr, in_req, in_ack,
	addr, data, , wr, req, ack);

// PPU video frame buffer
ppu_fb #(AN, DN, TFT_BASE, 9, 9,
	PPU_X, PPU_Y, TFT_LS) fb0 (clkSYS, clkPPU, n_reset,
	arb_addr[ppu], arb_data[ppu], arb_req[ppu], arb_wr[ppu], arb_ack[ppu],
	video_rgb, video_vblank, video_hblank, fb_empty, fb_full);

// Debug processor frame buffer
debug_fb #(AN, DN, TFT_BASE) debug0 (clkSYS, clkDebug, n_reset,
	arb_addr[dbg], arb_data[dbg], arb_req[dbg], arb_wr[dbg], arb_ack[dbg],
	dbg_addr, dbg_data, dbg_req, dbg_empty, dbg_full);

// Rectangular background fill
logic rect_active;
rectfill #(AN, DN, TFT_BASE, 9, 9, TFT_LS,
	// x-offset, y-offset, x-length, y-length
	PPU_X - MARGIN, PPU_Y - MARGIN, PPU_W + MARGIN * 2, PPU_H + MARGIN * 2)
	rect0 (clkSYS, n_reset, arb_addr[rect], arb_data[rect],
	arb_req[rect], arb_wr[rect], arb_ack[rect],
	~KEY[0], rect_active);

// Memory RW test client
`ifdef MODEL_TECH
mem_test #(BURST, TFT_BASE + 24'h010000, 24'h000010) test0 (clkSYS, n_reset,
	mem, valid, arb_addr[test], arb_data[test],
	arb_req[test], arb_wr[test], arb_ack[test],
	test_fail, SW[2], ~KEY[1], SW[3]);
`else
mem_test #(BURST, TFT_BASE + 24'h002000, 24'h010000) test0 (clkSYS, n_reset,
	mem, valid, arb_addr[test], arb_data[test],
	arb_req[test], arb_wr[test], arb_ack[test],
	test_fail, SW[2], ~KEY[1], SW[3]);
`endif

endmodule
