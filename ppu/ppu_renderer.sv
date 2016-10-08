module ppu_renderer (
	input logic n_reset, clkPPU,
	input logic bg_en, sp_en,
	// Bus interface
	output logic [13:0] addr,
	input logic [7:0] data,
	output logic req,
	// Rendering output
	output logic [8:0] out_x, out_y,
	output logic [23:0] out_rgb,
	output logic out_we
);

assign addr = 14'h0;
assign req = 1'b0;

// NTSC, PAL & Dendy parameters
parameter vblanking = 20, post = 1;
parameter vlines = 240 + post + vblanking + 1;

// Frame counters
always_ff @(posedge clkPPU, negedge n_reset)
	if (~n_reset)
		out_x <= 0;
	else if (out_x == 340)
		out_x <= 0;
	else
		out_x <= out_x + 1;

always_ff @(posedge clkPPU, negedge n_reset)
	if (~n_reset)
		out_y <= vlines - 1;
	else if (out_x == 340) begin
		if (out_y == vlines - 1)
			out_y <= 0;
		else
			out_y <= out_y + 1;
	end

endmodule
