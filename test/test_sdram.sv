`timescale 1 us / 1 ns

module test_sdram;

logic n_reset, clk, en;
assign en = 1'b1;

logic [12:0] DRAM_ADDR;
logic [1:0] DRAM_BA, DRAM_DQM;
logic DRAM_CKE, DRAM_CLK;
logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;
wire [15:0] DRAM_DQ;

logic dram_we;
logic [15:0] dram_data;
assign DRAM_DQ = dram_we ? dram_data : 16'bz;
assign dram_we = 1'b1;

logic [23:0] addr_in;
logic [15:0] data_in;
logic we, req, rdy;

logic [23:0] addr_out;
logic [15:0] data_out;
logic rdy_out;

assign data_in = 16'bx;
assign we = 1'b0, req = rdy;

sdram sdram0 (.*);

initial
begin
	addr_in = 24'h0;
	forever #1us addr_in += 24'h000040;
end

initial
begin
	dram_data = 16'ha5c3;
	#500ns;
	forever #1us dram_data++;
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
