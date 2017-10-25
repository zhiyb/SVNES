module apu_length_counter (
	input logic clk, dclk, n_reset,

	input logic hframe,
	input logic en, halt, load_cpu,
	input logic [4:0] idx,
	output logic act, gate
);

logic load;
flag_keeper flag0 (.n_reset(n_reset),
	.clk(clk), .flag(load_cpu), .clk_s(hframe), .clr(1'b1), .out(load));

logic [7:0] cnt, cnt_load;
assign act = cnt != 8'h0;
apu_rom_length rom0 (.address(idx), .aclr(~n_reset), .clock(dclk), .q(cnt_load));

always_ff @(posedge hframe, negedge n_reset, negedge en)
	if (~n_reset || ~en) begin
		cnt <= 8'b0;
		gate <= 1'b0;
	end else begin
		gate <= cnt != 8'b0;
		if (load)
			cnt <= cnt_load;
		else if (~halt && cnt != 8'b0)
			cnt <= cnt - 8'b1;
	end

endmodule
