`timescale 1 us / 1 ns

module test_sdram;

logic n_reset, clk, en;
logic [12:0] DRAM_ADDR;
logic [1:0] DRAM_BA, DRAM_DQM;
logic DRAM_CKE, DRAM_CLK;
logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;
wire [15:0] DRAM_DQ;

assign en = 1'b1;

logic we;
logic [15:0] data;
assign DRAM_DQ = we ? data : 1'bz;
assign we = 1'b0;

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
