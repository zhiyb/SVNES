`timescale 1 ns / 1 ns

module test_debug;

logic clkDebug, n_reset;
logic [19:0] addr;
logic [15:0] data;
logic req;

debug d0 (clkDebug, n_reset, addr, data, req);

localparam AN = 24, DN = 16, BASE = 24'hfa0000;

logic clkSYS;
assign clkSYS = clkDebug;
// Memory interface
logic [AN - 1:0] mem_addr;
logic [DN - 1:0] mem_data;
logic mem_req, mem_wr;
logic mem_ack;
// Status
logic empty, full;

debug_fb #(AN, DN, BASE) fb0 (clkSYS, clkDebug, n_reset,
	mem_addr, mem_data, mem_req, mem_wr, mem_ack,
	addr, data, req, empty, full);

always_ff @(posedge clkSYS)
	mem_ack <= ~mem_ack & mem_req;

initial
begin
	clkDebug = 1'b0;
	forever #1ns clkDebug = ~clkDebug;
end

initial
begin
	n_reset = 1'b0;
	#2ns n_reset = 1'b1;
end

endmodule
