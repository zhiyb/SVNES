module arbiter_sync_pri #(parameter AN, DN, N) (
	input logic clkSYS, n_reset,

	// Memory interface
	arbiter_if mem,
	input logic [DN - 1:0] mem_data,
	input logic [N - 1:0] mem_id,

	// Arbiter interface
	arbiter_if arb[4]
);

logic [AN - 1:0] arb_addr[2 ** N];
logic [DN - 1:0] arb_data[2 ** N];
logic arb_req[2 ** N], arb_wr[2 ** N];

genvar i;
generate
for (i = 0; i != 2 ** N; i++) begin: arb_net
	assign arb_addr[i] = arb[i].addr;
	assign arb_data[i] = arb[i].data;
	assign arb_req[i] = arb[i].req;
	assign arb_wr[i] = arb[i].wr;
	assign arb[i].id = i;

	always_ff @(posedge clkSYS)
	begin
		arb[i].ack <= mem.ack && mem.id == arb[i].id;
		arb[i].valid <= mem.valid && mem_id == arb[i].id;
		arb[i].mem <= mem_data;
	end
end
endgenerate

logic mem_ack_latch;
always_ff @(posedge clkSYS)
	mem_ack_latch <= mem.ack;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		mem.req <= 1'b0;
		mem.addr <= 0;
		mem.data <= 0;
		mem.id <= 2'b00;
		mem.wr <= 1'b0;
	end else if (mem.ack || mem_ack_latch) begin
		mem.req <= 1'b0;
		mem.addr <= 'x;
		mem.data <= 'x;
		mem.id <= 'x;
		mem.wr <= 'x;
	end else if (~mem.req) begin
		// Priority
		int i;
		for (i = 0; i != 2 ** N; i++) begin
			if (arb_req[i]) begin
				mem.req <= 1'b1;
				mem.addr <= arb_addr[i];
				mem.data <= arb_data[i];
				mem.id <= i;
				mem.wr <= arb_wr[i];
				break;
			end
		end
		if (i == 2 ** N) begin
			mem.req <= 1'b0;
			mem.addr <= 'x;
			mem.data <= 'x;
			mem.id <= 'x;
			mem.wr <= 'x;
		end
	end

endmodule
