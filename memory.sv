module memory #(parameter AN, DN, IN, BURST) (
	input logic clkSYS, clkSDRAM, n_reset,
	output logic n_reset_mem,

	input logic [AN - 1:0] arb_addr[IN],
	input logic [DN - 1:0] arb_data[IN],
	input logic arb_wr[IN],

	input logic [IN - 1:0] arb_req,
	output logic [IN - 1:0] arb_grant,
	output logic [IN - 1:0] arb_ack,

	output logic [DN - 1:0] mem_data_out,
	output logic [IN - 1:0] arb_valid,

	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ,

	output logic [1:0] sdram_level,
	output logic sdram_empty, sdram_full
);

// Memory interface
// Input interface
logic [AN - 1:0] mem_addr;
logic [DN - 1:0] mem_data;
logic [IN - 1:0] mem_id;
logic mem_req, mem_wr, mem_ack;
// Output interface
logic [IN - 1:0] mem_id_out;
logic mem_valid;
assign arb_ack = mem_id & {IN{mem_ack}};
assign arb_valid = mem_id_out & {IN{mem_valid}};

// Memory access arbiter
logic [IN - 1:0] arb_rot, arb_vo;
assign arb_rot = 1;	// Fixed priority
arbiter #(.N(IN)) arb_mem (arb_req, arb_grant, arb_rot, {IN{1'b1}}, , arb_vo);

always_ff @(posedge clkSYS)
	if (~mem_req)
		mem_id <= arb_grant;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		mem_req <= 1'b0;
	else if (mem_ack)
		mem_req <= 1'b0;
	else if (~mem_req)
		mem_req <= ~arb_vo[IN - 1];

logic [1:0] arb_idx;
always_ff @(posedge clkSYS)
	if (~mem_req) begin
		arb_idx[0] <= arb_vo[0] & ~(arb_vo[2] ^ arb_vo[1]);
		arb_idx[1] <= arb_vo[1];
	end

assign mem_addr = arb_addr[arb_idx];
assign mem_data = arb_data[arb_idx];
assign mem_wr = arb_wr[arb_idx];

// SDRAM
sdram #(AN, DN, IN, BURST) sdram0
	(clkSYS, clkSDRAM, n_reset, n_reset_mem,
	mem_data_out, mem_id_out, mem_valid,
	mem_addr, mem_data, mem_id, mem_req, mem_wr, mem_ack,
	DRAM_DQ, DRAM_ADDR, DRAM_BA, DRAM_DQM,
	DRAM_CLK, DRAM_CKE, DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	sdram_empty, sdram_full, sdram_level);
endmodule
