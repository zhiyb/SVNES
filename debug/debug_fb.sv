module debug_fb #(parameter AN, DN, BASE) (
	input logic clkSYS, clkDebug, n_reset,
	// Memory interface
	output logic [AN - 1:0] mem_addr,
	output logic [DN - 1:0] mem_data,
	output logic mem_req, mem_wr,
	input logic mem_ack,
	// Processor requests
	input logic [19:0] addr,
	input logic [15:0] data,
	input logic req,
	// Status
	output logic empty, full
);

// Request FIFO
logic rdreq, wrreq;
debug_fb_fifo fifo0 (~n_reset, {addr, data}, clkSYS, rdreq, clkDebug, wrreq,
	{mem_addr[19:0], mem_data}, empty, full);

assign wrreq = req;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		rdreq <= 1'b0;
	else if (rdreq | mem_req)
		rdreq <= 1'b0;
	else
		rdreq <= ~empty;

// Memory request
assign mem_wr = 1'b1;
assign mem_addr[AN - 1:20] = BASE[AN - 1:20];

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		mem_req <= 1'b0;
	else if (mem_ack)
		mem_req <= 1'b0;
	else if (rdreq)
		mem_req <= 1'b1;

endmodule
