module demux #(parameter N) (
	input logic [N - 1 : 0] sel,
	output logic [2 ** N - 1 : 0] q
);

always_comb
begin
	q <= {2 ** N{1'b0}};
	q[sel] <= 1'b1;
end

endmodule
