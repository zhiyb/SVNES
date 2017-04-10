module sdram #(
	// Address bus size, data bus size
	parameter AN = 24, DN = 16, BURST = 8,
	tRC = 8, tRAS = 6, tRP = 2, tRCD = 2,
	tRRD_tMRD = 2, tDPL = 2, tQMD = 2,
	tINIT = 9000, tREF = 704,
	logic [2:0] CAS = 2
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

// Data structures
typedef enum logic [4:0] {NOP, MRS, PALL, REF,
	ACT, PRE, READ, READA, WRITE, WRITEA} cmd_t;
typedef struct packed {
	cmd_t cmd;
	logic [1:0] ba;
	struct packed {
		logic [8:0] column;
		logic [15:0] data;
	} d;
} data_t;

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

// {{{ Initialisation and auto refresh
logic [3:0] icnt_ovf_latch;
logic [13:0] icnt;
always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset) begin
		icnt <= tINIT;
		icnt_ovf_latch[0] <= 1'b0;
	end else if (icnt == 14'h0) begin
		icnt <= tREF;
		icnt_ovf_latch[0] <= 1'b1;
	end else begin
		icnt <= icnt - 1;
		icnt_ovf_latch[0] <= 1'b0;
	end

always_ff @(posedge clkSYS)
	icnt_ovf_latch[3:1] <= icnt_ovf_latch[2:0];

logic icnt_ovf, icnt_ovf_clr;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		icnt_ovf <= 1'b0;
	else if (icnt_ovf_latch[2] && ~icnt_ovf_latch[3])
		icnt_ovf <= 1'b1;
	else if (icnt_ovf_clr)
		icnt_ovf <= 1'b0;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		n_reset_mem <= 1'b0;
	else if (icnt_ovf)
		n_reset_mem <= 1'b1;
// }}}

// {{{ Command sequence FIFO
data_t fifo_in, fifo_out;

logic [12:0] fifo_out_row;
assign fifo_out_row = fifo_out.d.data[12:0];

logic fifo_rdreq, fifo_wrreq;
sdram_fifo fifo0 (~n_reset, fifo_in,
	clkSDRAM, fifo_rdreq, clkSYS, fifo_wrreq,
	fifo_out, empty, full, level);
// }}}

// {{{ Command generation
// Command status
enum int unsigned {Powerup, IPrecharge, IRefresh, IRefresh2, IMode,
	Idle, PrechargeAll, Refresh,
	Request, Active, Precharge, Read, Write} state;

logic stall;
assign stall = full;

// Request interpret
logic [1:0] req_ba;
logic [8:0] req_column;
logic [12:0] req_row;
assign {req_ba, req_row, req_column} = req_addr;

// System interface
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		req_ack <= 1'b0;
	else if (~stall && (state == Read || state == Write))
		req_ack <= 1'b1;
	else
		req_ack <= 1'b0;

logic wrreq;
assign fifo_wrreq = wrreq && ~stall;

// Bank statuses
logic [3:0] active, match;
logic [12:0] bank_row[4];

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		active <= 4'b0000;
		match <= 4'b0000;
		for (int i = 0; i < 4; i++)
			bank_row[i] <= 0;
	end else begin
		if (state == Active) begin
			active[req_ba] <= 1'b1;
			bank_row[req_ba] <= req_row;
		end else if (state == Precharge)
			active[req_ba] <= 1'b0;
		else if (state == PrechargeAll)
			active <= 4'b0000;
		for (int i = 0; i < 4; i++)
			match[i] <= active[i] && req_row == bank_row[i];
	end

// Periodic refresh clear
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		icnt_ovf_clr <= 1'b0;
	else if (~stall && (state == Powerup || state == Idle))
		icnt_ovf_clr <= 1'b1;
	else
		icnt_ovf_clr <= 1'b0;

// Command sequencer
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		state <= Powerup;
		fifo_in.cmd <= NOP;
		wrreq <= 1'b0;
	end else if (~stall) begin
		if (state == Powerup) begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			if (icnt_ovf)
				state <= IPrecharge;
		end else if (state == IPrecharge) begin
			fifo_in.cmd <= PALL;
			wrreq <= 1'b1;
			state <= IRefresh;
		end else if (state == IRefresh) begin
			fifo_in.cmd <= REF;
			wrreq <= 1'b1;
			state <= IRefresh2;
		end else if (state == IRefresh2) begin
			fifo_in.cmd <= REF;
			wrreq <= 1'b1;
			state <= IMode;
		end else if (state == IMode) begin
			fifo_in.cmd <= MRS;
			wrreq <= 1'b1;
			state <= Idle;
		end else if (state == PrechargeAll) begin
			fifo_in.cmd <= PALL;
			wrreq <= 1'b1;
			state <= Refresh;
		end else if (state == Refresh) begin
			fifo_in.cmd <= REF;
			wrreq <= 1'b1;
			state <= req ? Request : Idle;
		end else if (state == Idle) begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			if (icnt_ovf)
				state <= PrechargeAll;
			else if (req && ~req_ack)
				state <= Request;
		end else if (state == Request) begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			if (match[req_ba])
				state <= req_wr ? Write : Read;
			else if (active[req_ba])
				state <= Precharge;
			else
				state <= Active;
		end else if (state == Precharge) begin
			fifo_in.cmd <= PRE;
			wrreq <= 1'b1;
			state <= Active;
		end else if (state == Active) begin
			fifo_in.cmd <= ACT;
			wrreq <= 1'b1;
			state <= req_wr ? Write : Read;
		end else if (state == Read) begin
			fifo_in.cmd <= READ;
			wrreq <= 1'b1;
			state <= Idle;
		end else if (state == Write) begin
			fifo_in.cmd <= WRITE;
			wrreq <= 1'b1;
			state <= Idle;
		end else begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			state <= Idle;
		end
	end

// Data generation
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		fifo_in.ba <= 2'h0;
		fifo_in.d <= 26'h0;
	end else if (~stall) begin
		if (state == Read) begin
			fifo_in.ba <= req_ba;
			fifo_in.d.column <= req_column;
			fifo_in.d.data <= {14'bx, req_id};
		end else if (state == Write) begin
			fifo_in.ba <= req_ba;
			fifo_in.d.column <= req_column;
			fifo_in.d.data <= req_data;
		end else if (state == Active) begin
			fifo_in.ba <= req_ba;
			fifo_in.d.column <= 'x;
			fifo_in.d.data <= {4'bx, req_row};
		end else if (state == Precharge) begin
			fifo_in.ba <= req_ba;
			fifo_in.d <= 'x;
		end else begin
			fifo_in.ba <= 'x;
			fifo_in.d <= 'x;
		end
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

logic [1:0] data_valid_latch;
always_ff @(posedge clkSDRAM, negedge n_reset)
	if (~n_reset)
		data_valid_latch <= 0;
	else if (data_latch[tLATCH - 2].valid) begin
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
	data_id[0] <= data_latch[tLATCH - 1].id;
	data_id[1] <= data_id[0];
	data[0] <= DRAM_DQ_d;
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
