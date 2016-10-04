module fifo_sync #(parameter DEPTH_N) (
	input logic clk, n_reset,
	input logic wrreq, rdack, flush,
	output logic empty, full, underrun, overrun,
	output logic [DEPTH_N - 1:0] head, tail
);

logic [2 ** DEPTH_N:0] level, level_n;
assign empty = level[0];
assign full = level[2 ** DEPTH_N];
always_comb
begin
	level_n = level;
	if (rdack) begin
		logic ovf;
		{level_n, ovf} = {1'b0, level};
		level_n[0] |= ovf;
	end
	if (wrreq) begin
		logic ovf;
		{ovf, level_n} = {level_n, 1'b0};
		level_n[2 ** DEPTH_N] |= ovf;
	end
end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		head <= {DEPTH_N{1'b0}};
		tail <= {DEPTH_N{1'b0}};
		level <= 1;
		underrun <= 1'b0;
		overrun <= 1'b0;
	end else if (flush) begin
		head <= {DEPTH_N{1'b0}};
		tail <= {DEPTH_N{1'b0}};
		level <= 1;
		underrun <= 1'b0;
		overrun <= 1'b0;
	end else begin
		if (rdack & ~empty)
			tail <= tail + 1;
		if (wrreq & ~full)
			head <= head + 1;
		level <= level_n;
		underrun <= empty & rdack;
		overrun <= full & wrreq;
	end

endmodule
