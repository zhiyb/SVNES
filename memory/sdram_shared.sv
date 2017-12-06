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
	output logic [DN - 1:0] mem_data_out,
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

// Memory interface
// Input interface
logic [AN - 1:0] mem_addr;
logic [DN - 1:0] mem_data;
logic [IN - 1:0] mem_id;
logic mem_req, mem_wr, mem_ack;
// Output interface
logic [IN - 1:0] mem_id_out;
logic mem_valid;
assign arb_valid = mem_id_out & {IN{mem_valid}};

// Request buffering
logic [AN - 1:0] addr[IN];
logic [DN - 1:0] data[IN];
logic wr[IN];
logic [IN - 1:0] req;

genvar i;
generate
for (i = 0; i != IN; i++) begin: reqbuf
	always_ff @(posedge clkSYS)
		if (arb_req[i] & ~req[i]) begin
			addr[i] <= arb_addr[i];
			data[i] <= arb_data[i];
			wr[i] <= arb_wr[i];
		end

	always_ff @(posedge clkSYS, negedge n_reset)
		if (~n_reset)
			req[i] <= 1'b0;
		else if (req[i])
			req[i] <= ~(mem_id[i] & mem_ack);
		else if (arb_req[i])
			req[i] <= 1'b1;

	assign arb_ack[i] = arb_req[i] & ~req[i];
end
endgenerate

// Memory access arbiter
logic [IN - 1:0] rot, vo;
logic [IN - 1:0] grant;
assign rot = 1;	// Fixed priority
arbiter #(.N(IN)) arb0 (req, grant, rot, {IN{1'b1}}, , vo);

always_ff @(posedge clkSYS)
	if (~mem_req)
		mem_id <= grant;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		mem_req <= 1'b0;
	else if (mem_ack)
		mem_req <= 1'b0;
	else if (~mem_req)
		mem_req <= ~vo[IN - 1];

logic [1:0] idx;
always_ff @(posedge clkSYS)
	if (~mem_req) begin
		idx[0] <= vo[0] & ~(vo[2] ^ vo[1]);
		idx[1] <= vo[1];
	end

assign mem_addr = addr[idx];
assign mem_data = data[idx];
assign mem_wr = wr[idx];

// SDRAM
sdram #(AN, DN, IN, BURST) sdram0
	(clkSYS, clkSDRAM, n_reset, n_reset_mem,
	mem_data_out, mem_id_out, mem_valid,
	mem_addr, mem_data, mem_id, mem_req, mem_wr, mem_ack,
	DRAM_DQ, DRAM_ADDR, DRAM_BA, DRAM_DQM,
	DRAM_CLK, DRAM_CKE, DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	sdram_empty, sdram_full, sdram_level);
endmodule
