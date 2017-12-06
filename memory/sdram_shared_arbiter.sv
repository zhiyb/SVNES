module sdram_shared_arbiter #(parameter AN, DN, IN) (
	input logic clkSYS, n_reset,

	// Access requests
	input logic [AN - 1:0] arb_addr[IN],
	input logic [DN - 1:0] arb_data[IN],
	input logic arb_wr[IN],

	input logic [IN - 1:0] arb_req,
	output logic [IN - 1:0] arb_ack,

	// Memory request
	output logic [AN - 1:0] mem_addr,
	output logic [DN - 1:0] mem_data,
	output logic [IN - 1:0] mem_id,
	output logic mem_wr,

	output logic mem_req,
	input logic mem_ack
);

// Memory access arbiter
logic [IN - 1:0] rot, vo;
logic [IN - 1:0] grant;
assign rot = 1;	// Fixed priority
arbiter #(.N(IN)) arb0 (arb_req, grant, rot, {IN{1'b1}}, , vo);

always_ff @(posedge clkSYS)
	if (~mem_req)
		mem_id <= grant;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		mem_req <= 1'b0;
	else if (mem_ack)
		mem_req <= 1'b0;
	else if (~mem_req)
		mem_req <= ~vo[IN - 1];

logic [1:0] idx;
always_ff @(posedge clkSYS)
	if (~mem_req) begin
		idx[0] <= vo[0] & ~(vo[2] ^ vo[1]);
		idx[1] <= vo[1];
	end

assign mem_addr = arb_addr[idx];
assign mem_data = arb_data[idx];
assign mem_wr = arb_wr[idx];
assign arb_ack = mem_id & {IN{mem_ack}};

endmodule
