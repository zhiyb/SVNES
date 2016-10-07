module tft_write (
	input logic n_reset,
	// Input data interface
	input logic clkData, we,
	input logic [23:0] addr_in,
	input logic [15:0] data_in,
	output logic overrun,
	// High speed data interface
	input logic clk,
	output logic req,
	input logic rdy,
	output logic [23:0] addr,
	output logic [15:0] data
);

logic data_req_reg;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		data_req_reg <= 1'b0;
	else
		data_req_reg <= we & ~clkData;

logic data_req;
flag_detector flag0 (.flag(data_req_reg), .out(data_req), .*);

// FIFO controller
logic rdack;
logic empty, full, underrun;
logic [2:0] head, tail;
fifo_sync #(.DEPTH_N(3)) fifo0 (.flush(1'b0),
	.wrreq(data_req), .*);

// FIFO data RAM
logic [39:0] fifo;
assign {addr, data} = fifo;
ramdual8x40 ram0 (.aclr(~n_reset), .clock(clk), .data({addr_in, data_in}), .q(fifo),
	.rdaddress(tail), .wraddress(head), .wren(1'b1));

// Data interface control
assign req = ~empty;
assign rdack = req & rdy;

endmodule
