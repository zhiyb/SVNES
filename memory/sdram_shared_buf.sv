module sdram_shared_buf #(parameter AN, DN, IN, IDN = IN) (
	input logic clkSYS, n_reset,

	// Inputs
	input logic [AN - 1:0] in_addr[IN],
	input logic [DN - 1:0] in_data[IN],
	input logic [IDN - 1:0] in_id[IN],
	input logic in_wr[IN],

	input logic [IN - 1:0] in_req,
	output logic [IN - 1:0] in_ack,

	// Outputs
	output logic [AN - 1:0] out_addr[IN],
	output logic [DN - 1:0] out_data[IN],
	output logic [IDN - 1:0] out_id[IN],
	output logic out_wr[IN],

	output logic [IN - 1:0] out_req,
	input logic [IN - 1:0] out_ack
);

// Request buffering
genvar i;
generate
for (i = 0; i != IN; i++) begin: reqbuf
	always_ff @(posedge clkSYS)
		if (in_req[i] & ~out_req[i]) begin
			out_addr[i] <= in_addr[i];
			out_data[i] <= in_data[i];
			out_id[i] <= in_id[i];
			out_wr[i] <= in_wr[i];
		end

	always_ff @(posedge clkSYS, negedge n_reset)
		if (~n_reset)
			out_req[i] <= 1'b0;
		else if (out_req[i])
			out_req[i] <= ~out_ack[i];
		else if (in_req[i])
			out_req[i] <= 1'b1;

	assign in_ack[i] = in_req[i] & ~out_req[i];
end
endgenerate

endmodule
