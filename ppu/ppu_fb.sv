// PPU memory frame buffer controller
module ppu_fb #(
	// Address bus size, data bus size
	parameter AN = 24, DN = 16, BASE,
	// x-counter bits, y-counter bits, x-offset, y-offset, line size
	XN = 8, YN = 8, XOFF = 0, YOFF = 0, LS = 256
) (
	input logic clkSYS, clkPPU, n_reset,

	// Memory interface
	output logic [AN - 1:0] addr,
	output logic [DN - 1:0] data,
	output logic req, wr,
	input logic ack,

	// Video input
	input logic [23:0] video_rgb,
	input logic video_vblank, video_hblank
);

// Data FIFO
logic [15:0] in, out;
logic rdreq, wrreq, rdempty, wrfull;
ppu_fb_fifo fifo0 (in, clkSYS, rdreq, clkPPU, wrreq, out, rdempty, wrfull);

assign in = {video_rgb[23:19], video_rgb[15:10], video_rgb[7:3]};
assign wrreq = ~(video_vblank | video_hblank);
assign rdreq = ~rdempty & ~req;
assign data = out;

// Synchronisation
logic [2:0] ppu, hblank;
logic [1:0] vblank;
logic sync, hsync;
always_ff @(posedge clkSYS)
begin
	ppu <= {ppu[1:0], ~clkPPU};
	// PPU clock falling edge
	sync <= ~ppu[2] & ppu[1];
	vblank <= {vblank[0], video_vblank};
	hblank <= {hblank[1:0], video_hblank};
	// Horizontal blank rising edge
	hsync <= ~hblank[2] & hblank[1];
end

// Memory interface
assign wr = 1'b1;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		req <= 1'b0;
	else if (req)
		req <= ~ack;
	else
		req <= ~rdempty;

// Address generation
localparam RELOAD = BASE + YOFF * LS + XOFF;
logic [AN - 1:0] yaddr;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		yaddr <= RELOAD;
	else if (vblank[1])
		yaddr <= RELOAD;
	else if (hsync)
		yaddr <= yaddr + LS;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		addr <= RELOAD;
	else if (hblank[1])
		addr <= yaddr;
	else if (rdreq)
		addr <= addr + 1;

endmodule
