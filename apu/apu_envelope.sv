module apu_envelope (
	sys_if sys,
	input logic qframe,
	input logic restart_cpu, loop, vol_con,
	input logic [3:0] period,
	output logic [3:0] out
);

logic restart;
flag_keeper flag0 (.n_reset(sys.n_reset),
	.clk(sys.clk), .flag(restart_cpu),
	.clk_s(qframe), .clr(1'b1), .out(restart));

// Envelope divider & decay counter

logic [3:0] div_cnt, cnt;

always_ff @(posedge qframe, negedge sys.n_reset)
	if (~sys.n_reset) begin
		div_cnt <= 4'h0;
		cnt <= 4'h0;
	end else if (restart) begin
		div_cnt <= period;
		cnt <= 4'hf;
	end else if (div_cnt == 4'h0) begin
		div_cnt <= period;
		if (loop || cnt != 4'h0)
			cnt <= cnt - 4'h1;
	end else
		div_cnt <= div_cnt - 4'h1;

assign out = vol_con ? period : cnt;

endmodule
