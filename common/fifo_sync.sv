module fifo_sync #(parameter DEPTH_N) (
	input logic clk, n_reset,
	input logic wrreq, rdack,
	output logic empty, full, underrun, overrun,
	output logic [DEPTH_N - 1:0] head, tail, level
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		head <= {DEPTH_N{1'b0}};
		tail <= {DEPTH_N{1'b0}};
		level <= {DEPTH_N{1'b0}};
		full <= 1'b0;
		underrun <= 1'b0;
		overrun <= 1'b0;
	end else begin
		if (rdack & ~empty) begin
			level <= level - 1;
			full <= 1'b0;
			head <= head + 1;
		end
		if (wrreq & ~full) begin
			level <= level + 1;
			full <= level + 1 == {DEPTH_N{1'b0}};
			tail <= tail + 1;
		end
		underrun <= empty & rdack;
		overrun <= full & wrreq;
	end

assign empty = {full, level} == {1 + DEPTH_N{1'b0}};

endmodule
