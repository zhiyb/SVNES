import sdram_types::*;

module sdram_io #(
	parameter BURST = 8,
	tRC = 8, tRAS = 6, tRP = 2, tRCD = 2,
	tRRD_tMRD = 2, tDPL = 2, tQMD = 2,
`ifdef MODEL_TECH
	tINIT = 10, tREF = 704,
`else
	tINIT = 9000, tREF = 704,
`endif
	logic [2:0] CAS = 2
) (
	input logic clkSDRAM, n_reset,

	// Periodic counter
	output logic icnt_ovf,

	// FIFO interface
	input logic empty,
	output logic fifo_rdreq,
	input data_t fifo_out,

	// Data output interface
	output logic data_valid_io,
	output logic [1:0] data_id_io,
	output logic [15:0] data_io,

	// Hardware interface
	inout wire [15:0] DRAM_DQ,
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CLK, DRAM_CKE,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

// {{{ Initialisation and auto refresh
logic [3:0] icnt_ovf_latch;
logic [13:0] icnt;
always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset) begin
		icnt <= tINIT;
		icnt_ovf <= 1'b0;
	end else if (icnt == 14'h0) begin
		icnt <= tREF;
		icnt_ovf <= 1'b1;
	end else begin
		icnt <= icnt - 1;
		icnt_ovf <= 1'b0;
	end
// }}}

// Data structures
data_t dram;
logic [12:0] dram_row;
assign dram_row = dram.d.data[12:0];
logic [1:0] dram_id;
assign dram_id = dram.d.data[1:0];

// {{{ Logic IO operations
assign DRAM_CLK = clkSDRAM;

// Tri-state DQ
logic DRAM_DQ_out;
logic [15:0] DRAM_DQ_q, DRAM_DQ_d;
assign DRAM_DQ = DRAM_DQ_out ? DRAM_DQ_q : 16'bz;

always_ff @(posedge clkSDRAM)
	DRAM_DQ_d <= DRAM_DQ;

// Command output
always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset) begin
		DRAM_CKE <= 1'b1;
		DRAM_CS_N <= 1'b1;
		DRAM_RAS_N <= 1'b1;
		DRAM_CAS_N <= 1'b1;
		DRAM_WE_N <= 1'b1;
		DRAM_BA <= 2'b0;
		DRAM_DQM <= 2'b0;
		DRAM_ADDR <= 13'b0;
		DRAM_DQ_q <= 16'b0;
		DRAM_DQ_out <= 1'b0;
	end else begin
		DRAM_CKE <= 1'b1;
		DRAM_CS_N <= 1'b0;
		DRAM_DQM <= 2'b0;
		case (dram.cmd)
		PALL: begin	// Precharge all banks
			DRAM_RAS_N <= 1'b0;
			DRAM_CAS_N <= 1'b1;
			DRAM_WE_N <= 1'b0;
			DRAM_BA <= 2'bx;
			DRAM_ADDR <= {2'bx, 1'b1, 10'bx};
			DRAM_DQ_q <= 16'bx;
			DRAM_DQ_out <= 1'b0;
		end
		REF: begin	// CBR auto-refresh
			DRAM_RAS_N <= 1'b0;
			DRAM_CAS_N <= 1'b0;
			DRAM_WE_N <= 1'b1;
			DRAM_BA <= 2'bx;
			DRAM_ADDR <= 13'bx;
			DRAM_DQ_q <= 16'bx;
			DRAM_DQ_out <= 1'b0;
		end
		MRS: begin	// Mode register set
			DRAM_RAS_N <= 1'b0;
			DRAM_CAS_N <= 1'b0;
			DRAM_WE_N <= 1'b0;
			DRAM_BA <= 2'b0;
			// Reserved, no write burst, standard, CAS, sequential, burst length 8
			DRAM_ADDR <= {3'b0, 1'b1, 2'b0, CAS, 1'b0, 3'h3};
			DRAM_DQ_q <= 16'bx;
			DRAM_DQ_out <= 1'b0;
		end
		ACT: begin	// Bank activate
			DRAM_RAS_N <= 1'b0;
			DRAM_CAS_N <= 1'b1;
			DRAM_WE_N <= 1'b1;
			DRAM_BA <= dram.ba;
			DRAM_ADDR <= dram_row;
			DRAM_DQ_q <= 16'bx;
			DRAM_DQ_out <= 1'b0;
		end
		PRE: begin	// Precharge select bank
			DRAM_RAS_N <= 1'b0;
			DRAM_CAS_N <= 1'b1;
			DRAM_WE_N <= 1'b0;
			DRAM_BA <= dram.ba;
			DRAM_ADDR <= {2'bx, 1'b0, 10'bx};
			DRAM_DQ_q <= 16'bx;
			DRAM_DQ_out <= 1'b0;
		end
		READ: begin	// Read
			DRAM_RAS_N <= 1'b1;
			DRAM_CAS_N <= 1'b0;
			DRAM_WE_N <= 1'b1;
			DRAM_BA <= dram.ba;
			DRAM_ADDR <= dram.d.column;
			DRAM_DQ_q <= 16'bx;
			DRAM_DQ_out <= 1'b0;
		end
		WRITE: begin	// Write
			DRAM_RAS_N <= 1'b1;
			DRAM_CAS_N <= 1'b0;
			DRAM_WE_N <= 1'b0;
			DRAM_BA <= dram.ba;
			DRAM_ADDR <= dram.d.column;
			DRAM_DQ_q <= dram.d.data;
			DRAM_DQ_out <= 1'b1;
		end
		default: begin	// No operation
			DRAM_RAS_N <= 1'b1;
			DRAM_CAS_N <= 1'b1;
			DRAM_WE_N <= 1'b1;
			DRAM_BA <= 2'bx;
			DRAM_ADDR <= 13'bx;
			DRAM_DQ_q <= 16'bx;
			DRAM_DQ_out <= 1'b0;
		end
		endcase
	end
// }}}

// {{{ FIFO command receive
logic estall;
assign fifo_rdreq = ~empty && ~estall;

logic fifo_latch;
always_ff @(posedge clkSDRAM)
	if (~estall)
		fifo_latch <= fifo_rdreq;

data_t ex[5];
always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset)
		ex[0] <= {NOP, 2'h0, 25'h0};
	else if (~estall) begin
		if (fifo_latch)
			ex[0] <= fifo_out;
		else
			ex[0] <= {NOP, 2'h0, 25'h0};
	end

always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset) begin
		ex[4] <= 0;
		ex[3] <= 0;
		ex[2] <= 0;
		ex[1] <= 0;
	end else if (~estall) begin
		ex[4] <= ex[3];
		ex[3] <= ex[2];
		ex[2] <= ex[1];
		ex[1] <= ex[0];
	end

always_ff @(posedge clkSDRAM)
	if (~estall)
		dram <= ex[1];
	else
		dram <= {NOP, 2'h0, 25'h0};
// }}}

// {{{ Command execution
// Current bank check
logic current;
logic [1:0] current_bank;
always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset) begin
		current <= 0;
		current_bank <= 0;
	end else if (fifo_out.cmd == READ) begin
		current <= 1;
		current_bank <= fifo_out.ba;
	end else begin
		current <= fifo_out.ba == current_bank;
	end

// Latency counter reload
typedef struct packed {
	logic tBURST, tBURSTW;
	logic tRCD, tRC, tRRD_tMRD, tDPL;
	// TODO: bank specific tRCD
	logic [3:0] tRAS, tRP;
} cnt_t;
cnt_t reload, reload_next;

always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset)
		reload <= 0;
	else if (~estall)
		reload <= reload_next;

parameter reload_latency = 0;
always_comb
begin
	reload_next = 0;
	case (ex[reload_latency].cmd)
	MRS:	reload_next.tRRD_tMRD = 1;
	REF:	reload_next.tRC = 1;
	ACT:	begin
		reload_next.tRCD = 1;
		reload_next.tRRD_tMRD = 1;
		reload_next.tRAS[ex[reload_latency].ba] = 1;
	end
	PRE:	reload_next.tRP[ex[reload_latency].ba] = 1;
	PALL:	for (int i = 0; i != 4; i++)
			reload_next.tRP[i] = 1;
	READ:	begin
		reload_next.tBURST = 1;
		reload_next.tBURSTW = 1;
	end
	WRITE:	reload_next.tDPL = 1;
	endcase
end

// Latency counter check
cnt_t check, check_next;

always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset)
		check <= 0;
	else if (~estall)
		check <= check_next;

parameter check_latency = 0;
always_comb
begin
	check_next = 0;
	case (ex[check_latency].cmd)
	MRS:	check_next.tRC = 1;
	REF:	begin
		check_next.tRC = 1;
		for (int i = 0; i != 4; i++)
			check_next.tRP[i] = 1;
	end
	ACT:	begin
		check_next.tRC = 1;
		check_next.tRRD_tMRD = 1;
		check_next.tRP[ex[check_latency].ba] = 1;
	end
	PRE:	begin
		check_next.tBURST = current;
		check_next.tDPL = 1;
		check_next.tRAS[ex[check_latency].ba] = 1;
	end
	PALL:	begin
		check_next.tBURST = 1;
		check_next.tDPL = 1;
		for (int i = 0; i != 4; i++)
			check_next.tRAS[i] = 1;
	end
	READ:	begin
		check_next.tBURST = 1;
		check_next.tRCD = 1;
	end
	WRITE:	begin
		check_next.tBURSTW = 1;
		check_next.tRCD = 1;
	end
	endcase
end

// Latency counters
cnt_t ready;
sdram_cnt #(4, BURST) cnt_tBURST (clkSDRAM, n_reset,
	~estall && reload.tBURST, ready.tBURST);
sdram_cnt #(4, BURST + CAS + tQMD) cnt_tBURSTW (clkSDRAM, n_reset,
	~estall && reload.tBURSTW, ready.tBURSTW);
sdram_cnt #(2, tRCD) cnt_tRCD (clkSDRAM, n_reset,
	~estall && reload.tRCD, ready.tRCD);
sdram_cnt #(4, tRC) cnt_tRC (clkSDRAM, n_reset,
	~estall && reload.tRC, ready.tRC);
sdram_cnt #(1, tRRD_tMRD) cnt_tRRD_tMRD (clkSDRAM, n_reset,
	~estall && reload.tRRD_tMRD, ready.tRRD_tMRD);
sdram_cnt #(1, tDPL) cnt_tDPL (clkSDRAM, n_reset,
	~estall && reload.tDPL, ready.tDPL);

genvar i;
generate
for (i = 0; i < 4; i++) begin: bank
	sdram_cnt #(4, tRAS) cnt_tRAS (clkSDRAM, n_reset,
		~estall && reload.tRAS[i], ready.tRAS[i]);
	sdram_cnt #(2, tRP) cnt_tRP (clkSDRAM, n_reset,
		~estall && reload.tRP[i], ready.tRP[i]);
end
endgenerate

// Command latency check
assign estall = !(!(~ready & check));
// }}}

// {{{ Data output
parameter tLATCH = BURST + CAS + 1;
struct packed {
	logic valid;
	logic [1:0] id;
} data_latch[tLATCH];

generate
for (i = 0; i < BURST; i++) begin: latch
	always_ff @(posedge clkSDRAM, negedge n_reset)
		if (~n_reset)
			data_latch[i] <= 0;
		else if (dram.cmd == READ)
			data_latch[i] <= {1'b1, dram_id};
		else if (i == 0)
			data_latch[i] <= 0;
		else
			data_latch[i] <= data_latch[i - 1];
end

for (i = BURST; i < tLATCH; i++) begin: latch_latency
	always_ff @(posedge clkSDRAM, negedge n_reset)
		if (~n_reset)
			data_latch[i] <= 0;
		else
			data_latch[i] <= data_latch[i - 1];
end
endgenerate

assign data_valid_io = data_latch[tLATCH - 2].valid;
assign data_id_io = data_latch[tLATCH - 1].id;
assign data_io = DRAM_DQ_d;
// }}}

endmodule
