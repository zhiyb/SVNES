import sdram_types::*;

module sdram #(
	// Address bus size, data bus size
	parameter AN = 24, DN = 16, BURST = 8
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
	input logic req, req_wr,
	output logic req_ack,

	// Hardware interface
	inout wire [15:0] DRAM_DQ,
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CLK, DRAM_CKE,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	
	// Diagnostic signals
	output logic empty, full,
	output logic [1:0] level
);

// {{{ Initialisation and auto refresh
logic [3:0] icnt_ovf;
always_ff @(posedge clkSYS)
	icnt_ovf[3:1] <= icnt_ovf[2:0];

logic icnt_ovf_latch;
assign icnt_ovf_latch = icnt_ovf[2] && ~icnt_ovf[3];
// }}}

// Command buffer FIFO
data_t fifo_in, fifo_out;
logic fifo_wrreq, fifo_rdreq;
sdram_fifo fifo0 (~n_reset, fifo_in,
	clkSDRAM, fifo_rdreq, clkSYS, fifo_wrreq,
	fifo_out, empty, full, level);

// Command generation
sdram_sys #(AN, DN, BURST) sys0 (.*);

// Command execution
logic data_valid_io;
logic [1:0] data_id_io;
logic [15:0] data_io;
sdram_io #(BURST) io0 (.icnt_ovf(icnt_ovf[0]), .*);

// {{{ Data output
logic [1:0] data_valid_latch;
always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset)
		data_valid_latch <= 0;
	else if (data_valid_io) begin
		data_valid_latch[1] <= data_valid_latch[0];
		data_valid_latch[0] <= ~data_valid_latch[0];
	end else
		data_valid_latch <= 0;

logic [2:0] data_valid[2];
always_ff @(posedge clkSYS, negedge n_reset) begin
	if (~n_reset) begin
		data_valid[0] <= 0;
		data_valid[1] <= 0;
	end else begin
		data_valid[0] <= {data_valid[0][1:0], data_valid_latch[0]};
		data_valid[1] <= {data_valid[1][1:0], data_valid_latch[1]};
	end
end

logic [1:0] data_id[2];
logic [15:0] data[2];
always_ff @(posedge clkSYS) begin
	data_id[0] <= data_id_io;
	data_id[1] <= data_id[0];
	data[0] <= data_io;
	data[1] <= data[0];
end

always_ff @(posedge clkSYS) begin
	mem_valid <= (data_valid[0][1] & ~data_valid[0][2]) ||
		(data_valid[1][1] & ~data_valid[1][2]);
	mem_data <= data[1];
	mem_id <= data_id[1];
end
// }}}

endmodule
