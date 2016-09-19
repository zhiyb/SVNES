`timescale 1 us / 1 ns

module test_cache;

logic n_reset, clk;
logic we, req;
logic miss, rdy;
logic [23:0] addr;
wire [15:0] data;
assign we = 1'b0, req = 1'b1;

logic [23:0] if_addr_out;
logic [15:0] if_data_out;
logic if_we, if_req;
logic if_rdy;
assign if_rdy = 1'b1;

logic [23:0] if_addr_in, if_addr_in_0;
logic [15:0] if_data_in;
logic if_rdy_in, if_rdy_in_0;

always_ff @(posedge clk)
begin
	if_addr_in_0 <= if_addr_out;
	if_rdy_in_0 <= if_req;
end

always_ff @(posedge clk)
begin
	if_addr_in <= if_addr_in_0;
	if_rdy_in <= if_rdy_in_0;
end

cache cache0 (.*);

initial
begin
	addr = 24'h0;
	forever #4us if (rdy) addr += 24'h1;
end

initial
begin
	if_data_in = 16'ha5c3;
	#500ns;
	forever #1us if_data_in++;
end

initial
begin
	n_reset = 1'b0;
	#1us n_reset = 1'b1;
end

initial
begin
	clk = 1'b0;
	forever #500ns clk = ~clk;
end

endmodule
