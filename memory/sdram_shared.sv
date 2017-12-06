module sdram_shared #(parameter AN, DN, IN, BURST) (
	input logic clkSYS, clkSDRAM, n_reset,
	output logic n_reset_mem,

	// Access request
	input logic [AN - 1:0] arb_addr[IN],
	input logic [DN - 1:0] arb_data[IN],
	input logic arb_wr[IN],

	input logic [IN - 1:0] arb_req,
	output logic [IN - 1:0] arb_ack,

	// Memory data return
	output logic [DN - 1:0] arb_data_out,
	output logic [IN - 1:0] arb_valid,

	// SDRAM IO
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ,

	// SDRAM FIFO status
	output logic [1:0] sdram_level,
	output logic sdram_empty, sdram_full
);

// Access request buffering
logic [AN - 1:0] in_addr[IN];
logic [DN - 1:0] in_data[IN];
logic in_wr[IN];
logic [IN - 1:0] in_req;
logic [IN - 1:0] in_ack;
sdram_shared_buf #(AN, DN, IN) buf0 (clkSYS, n_reset,
	arb_addr, arb_data, , arb_wr, arb_req, arb_ack,
	in_addr, in_data, , in_wr, in_req, in_ack);

// Memory access arbiter
logic [AN - 1:0] out_addr;
logic [DN - 1:0] out_data;
logic [IN - 1:0] out_id;
logic out_wr, out_req, out_ack;
sdram_shared_arbiter #(AN, DN, IN) arb0 (clkSYS, n_reset,
	in_addr, in_data, in_wr, in_req, in_ack,
	out_addr, out_data, out_id, out_wr, out_req, out_ack);

// Memory request interface
logic [AN - 1:0] mem_addr;
logic [DN - 1:0] mem_data;
logic [IN - 1:0] mem_id;
logic mem_wr, mem_req, mem_ack;

// Memory request buffering
sdram_shared_buf #(AN, DN, 1, IN) buf1 (clkSYS, n_reset,
	'{out_addr}, '{out_data}, '{out_id}, '{out_wr}, out_req, out_ack,
	'{mem_addr}, '{mem_data}, '{mem_id}, '{mem_wr}, mem_req, mem_ack);

// Memory output interface
logic [DN - 1:0] mem_data_out;
logic [IN - 1:0] mem_id_out;
logic mem_valid;

// Data output buffering
always_ff @(posedge clkSYS)
begin
	arb_data_out <= mem_data_out;
	arb_valid <= mem_id_out & {IN{mem_valid}};
end

// SDRAM
sdram #(AN, DN, IN, BURST) sdram0
	(clkSYS, clkSDRAM, n_reset, n_reset_mem,
	mem_data_out, mem_id_out, mem_valid,
	mem_addr, mem_data, mem_id, mem_req, mem_wr, mem_ack,
	DRAM_DQ, DRAM_ADDR, DRAM_BA, DRAM_DQM,
	DRAM_CLK, DRAM_CKE, DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	sdram_empty, sdram_full, sdram_level);
endmodule
