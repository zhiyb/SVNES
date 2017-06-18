// Asynchronous arbiter slice with N requests
module arbiter #(parameter N) (
	input logic [N - 1:0] request,
	output logic [N - 1:0] grant,
	input logic [N - 1:0] rotate,	// Priority
	input logic [N - 1:0] in,	// Left connections
	output logic [N - 1:0] out,	// Right connections
	output logic [N - 1:0] vo	// Vertical connections
);

logic [N:0] v;	// Vertical connections
logic [N - 1:0] up, left;
assign up = v[N - 1:0] | rotate;
assign left = in | rotate;
assign grant = request & up & left;
assign out = ~grant & left;
assign v[N:1] = ~grant & up;
assign v[0] = v[N];
assign vo = v[N:1];

endmodule
