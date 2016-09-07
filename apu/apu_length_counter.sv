module apu_length_counter (
	sys_if sys,
	input logic hframe,
	input logic en, halt, load_cpu,
	input logic [4:0] idx,
	output logic act, gate
);

logic load, load_clr;
always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		load <= 1'b0;
	else if (load_cpu)
		load <= 1'b1;
	else if (load_clr)
		load <= 1'b0;

logic [7:0] cnt, cnt_load;
assign act = cnt != 8'h0;
apu_rom_length rom0 (.address(idx), .aclr(~sys.n_reset), .clock(sys.nclk), .q(cnt_load));

always_ff @(posedge hframe, negedge sys.n_reset, negedge en)
	if (~sys.n_reset || ~en) begin
		cnt <= 8'b0;
		load_clr <= 1'b0;
		gate <= 1'b0;
	end else begin
		load_clr <= load;
		gate <= cnt != 8'b0;
		if (load)
			cnt <= cnt_load;
		else if (~halt && cnt != 8'b0)
			cnt <= cnt - 8'b1;
	end

endmodule
