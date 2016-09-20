module fifo_sync #(parameter DEPTH_N) (
	input logic clk, n_reset,
	input logic wrreq, rdack, flush,
	output logic empty, full, underrun, overrun,
	output logic [DEPTH_N - 1:0] head, tail, level
);

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		head <= {DEPTH_N{1'b0}};
		tail <= {DEPTH_N{1'b0}};
		level <= {DEPTH_N{1'b0}};
		empty <= 1'b1;
		full <= 1'b0;
		underrun <= 1'b0;
		overrun <= 1'b0;
	end else if (flush) begin
		head <= {DEPTH_N{1'b0}};
		tail <= {DEPTH_N{1'b0}};
		level <= {DEPTH_N{1'b0}};
		empty <= 1'b1;
		full <= 1'b0;
		underrun <= 1'b0;
		overrun <= 1'b0;
	end else begin
		if (rdack & ~empty)
			tail <= tail + 1;
		if (wrreq & ~full)
			head <= head + 1;
		if (rdack & ~empty & wrreq & ~full) begin
			empty <= 1'b0;
			full <= 1'b0;
		end else if (rdack & ~empty) begin
			level <= level - 1;
			empty <= level == 1;
			full <= 1'b0;
		end else if (wrreq & ~full) begin
			level <= level + 1;
			empty <= 1'b0;
			full <= level == {DEPTH_N{1'b1}};
		end
		underrun <= empty & rdack;
		overrun <= full & wrreq;
	end

endmodule
