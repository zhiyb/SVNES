module sdram_cnt #(parameter N, PERIOD) (
	input logic clk, n_reset, reload,
	output logic ready
);

logic [N - 1:0] cnt;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		cnt <= 0;
		ready <= 1'b1;
	end else if (reload) begin
		cnt <= PERIOD - 1;
		ready <= 1'b0;
	end else if (ready) begin
		cnt <= 0;
		ready <= 1'b1;
	end else begin
		cnt <= cnt - 1;
		ready <= cnt == 1;
	end

endmodule
