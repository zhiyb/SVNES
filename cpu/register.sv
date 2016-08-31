module register #(parameter reset = 8'h00) (
	sys_if sys,
	input logic we, oe,
	output logic [7:0] data,
	input logic [7:0] in,
	output wire [7:0] out
);

assign out = oe ? data : 8'bz;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		data <= reset;
	else if (we)
		data <= in;

endmodule
