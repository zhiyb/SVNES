module apu_mixer (
	input logic clk, dclk, n_reset,

	input logic [3:0] pulse[2], triangle, noise,
	input logic [6:0] dmc,
	output logic [7:0] out
);

logic [6:0] pulse_out;

apu_rom_pulse romp (.aclr(~n_reset), .clock(dclk),
	.address({1'b0, pulse[0]} + {1'b0, pulse[1]}), .q(pulse_out));

logic [7:0] tnd_out;

apu_rom_tnd romt (.aclr(~n_reset), .clock(dclk),
	.address(8'd3 * triangle + 8'd2 * noise + dmc), .q(tnd_out));

assign out = {1'b0, pulse_out} + tnd_out;

endmodule
