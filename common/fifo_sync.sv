module fifo_sync #(parameter N, DEPTH_N) (
	input logic clk, n_reset,
	input logic wrreq, rdack,
	output logic empty, full, underrun, overrun,
	input logic [N - 1:0] in,
	output logic [N - 1:0] out
);

logic [N - 1:0] data[2 ** DEPTH_N];
logic [DEPTH_N - 1:0] head, head_next, tail, tail_next, level;
assign head_next = rdack & ~empty ? head + {{DEPTH_N - 1{1'b0}}, 1'b1} : head;
assign tail_next = wrreq & ~full ? tail + {{DEPTH_N - 1{1'b0}}, 1'b1} : tail;
assign level = tail - head;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		for (int i = 0; i < 2 ** DEPTH_N; i++)
			data[i] <= {N{1'b0}};
		head <= {DEPTH_N{1'b0}};
		tail <= {DEPTH_N{1'b0}};
		empty <= 1'b1;
		full <= 1'b0;
		underrun <= 1'b0;
		overrun <= 1'b0;
	end else begin
		if (wrreq & ~full)
				data[tail] <= in;
		head <= head_next;
		tail <= tail_next;
		empty <= (empty | rdack) & tail_next == head_next;
		full <= (full | wrreq) & tail_next == head_next;
		underrun <= empty & rdack;
		overrun <= full & wrreq;
	end

assign out = data[head];

endmodule
