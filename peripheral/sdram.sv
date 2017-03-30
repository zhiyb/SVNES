module sdram #(
	// Address bus size, data bus size
	parameter AN = 22, DN = 16
) (
	input logic clkSYS, clkSDRAM,

	// System bus interface
	output logic [AN - 1:0] res_addr,
	output logic [DN - 1:0] res_data,
	input logic req,
	output logic rdy,

	// Hardware interface
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ
);

assign DRAM_CLK = clkSDRAM;

endmodule
