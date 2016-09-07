module apu_envelope (
	sys_if sys,
	input logic qframe,
	input logic restart_cpu, loop, vol_con,
	input logic [3:0] period,
	output logic [3:0] out
);

// Start signal holding logc

logic restart, restart_clr;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		restart <= 1'b0;
	else if (restart_clr)
		restart <= 1'b0;
	else if (restart_cpu)
		restart <= 1'b1;

always_ff @(posedge qframe, negedge sys.n_reset)
	if (~sys.n_reset)
		restart_clr <= 1'b0;
	else
		restart_clr <= restart;

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
