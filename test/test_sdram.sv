`timescale 1 us / 1 ns

module test_sdram;

logic n_reset, clk, en;
logic [12:0] DRAM_ADDR;
logic [1:0] DRAM_BA, DRAM_DQM;
logic DRAM_CKE, DRAM_CLK;
logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;
wire [15:0] DRAM_DQ;

assign en = 1'b1;

logic dram_we;
logic [15:0] dram_data;
assign DRAM_DQ = dram_we ? dram_data : 16'bz;
assign dram_we = 1'b1;
assign dram_data = 16'ha5c3;

logic [23:0] addr;
wire [15:0] data;
logic we, rd;
logic rdy;

assign addr = 24'h123456;
assign we = 1'b0, rd = 1'b1;

sdram sdram0 (.*);

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
