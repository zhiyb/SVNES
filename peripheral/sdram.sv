module sdram #(parameter CS = 3) (
	input logic clk, en,
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_CAS_N, DRAM_RAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ
);

assign DRAM_CLK = ~clk;
assign DRAM_CS_N = ~en;

endmodule
