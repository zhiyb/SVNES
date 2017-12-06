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
logic [17:0] in, out;
logic rdreq, wrreq, rdempty, wrfull;
ppu_fb_fifo fifo0 (in, clkSYS, rdreq, clkPPU, wrreq, out, rdempty, wrfull);

logic updated;
always_ff @(posedge clkSYS)
	updated <= rdreq;

assign wrreq = 1'b1;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		rdreq <= 1'b0;
	else
		rdreq <= ~rdempty & ~req & ~rdreq & ~updated;

assign in = {video_vblank, video_hblank, video_rgb[23:19], video_rgb[15:10], video_rgb[7:3]};
logic vblank, hblank, _hblank;
assign {vblank, hblank, data} = out;
always_ff @(posedge clkSYS)
	if (updated)
		_hblank <= hblank;

// Memory interface
assign wr = ~wrfull;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		req <= 1'b0;
	else if (req)
		req <= ~ack;
	else
		req <= updated & ~vblank & ~hblank;

// Address generation
localparam RELOAD = BASE + YOFF * LS + XOFF;
logic [AN - 1:0] _yaddr, yaddr;
always_ff @(posedge clkSYS)
	_yaddr <= yaddr + LS;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		yaddr <= RELOAD;
	else if (updated) begin
		if (vblank)
			yaddr <= RELOAD;
		else if (hblank & ~_hblank)
			yaddr <= _yaddr;
	end

logic [AN - 1:0] _xaddr, xaddr;
always_ff @(posedge clkSYS)
	_xaddr <= addr + 1;
always_ff @(posedge clkSYS)
	if (hblank | vblank)
		xaddr <= yaddr;
	else
		xaddr <= _xaddr;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		addr <= RELOAD;
	else if (updated)
		addr <= xaddr;

endmodule
