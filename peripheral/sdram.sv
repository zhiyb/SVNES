module sdram #(
	// Address bus size, data bus size
	parameter AN = 22, DN = 16, BURST = 8
) (
	input logic clkSYS, clkSDRAM, n_reset,
	output logic n_reset_mem,

	// Memory interface
	output logic [DN - 1:0] mem_data,
	output logic [1:0] mem_id,
	output logic mem_valid,

	// System bus request interface
	input logic [AN - 1:0] req_addr,
	input logic [DN - 1:0] req_data,
	input logic [1:0] req_id,
	input logic request,
	output logic req_ready,

	// Hardware interface
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ
);

assign DRAM_CLK = clkSDRAM;
assign n_reset_mem = 1'b1;

// Memory tests
logic [2:0] burst;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		mem_data <= 0;
		mem_valid <= 1'b0;
		mem_id <= 2'h0;
		burst <= 0;
		req_ready <= 1'b0;
	end else if (request && req_ready) begin
		mem_data <= req_addr[15:0];
		mem_valid <= 1'b1;
		mem_id <= req_id;
		burst <= BURST - 1;
		req_ready <= 1'b0;
	end else if (burst == 0) begin
		mem_valid <= 1'b0;
		req_ready <= 1'b1;
	end else begin
		mem_data <= mem_data + 1;
		mem_valid <= 1'b1;
		burst <= burst - 1;
		req_ready <= 1'b0;
	end

endmodule
