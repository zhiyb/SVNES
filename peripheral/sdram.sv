module sdram #(parameter logic [2:0] CAS = 3, BURST = 3'b000,
	int TINIT = 14300, TREFC = 1117,
	int TRC = 9, TRAS = 6, TRP = 3, TMRD = 2, TRCD = 3) (
	input logic n_reset, clk, en,
	
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ,
	
	input logic [23:0] addr_in,
	input logic [15:0] data_in,
	input logic we, req,
	output logic rdy,
	
	output logic [23:0] addr_out,
	output logic [15:0] data_out,
	output logic rdy_out
);

assign DRAM_CLK = ~clk;
assign DRAM_CS_N = ~en;

// Input synchronous FIFO

logic rdack, empty, full, underrun, overrun;
logic [40:0] fifo_in, fifo_out;
fifo_sync #(.N(41), .DEPTH_N(3)) fifo0 (.wrreq(req), .in(fifo_in), .out(fifo_out), .*);
// WE, BA[1:0], ROW[12:0], COLUMN[8:0], DATA[15:0]
assign fifo_in = {we, addr_in, data_in};
assign rdy = ~full;
logic fifo_we;
logic [1:0] fifo_ba;
logic [12:0] fifo_row;
logic [8:0] fifo_column;
logic [15:0] fifo_data;
logic [23:0] fifo_addr;
assign {fifo_we, fifo_ba, fifo_row, fifo_column, fifo_data} = fifo_out;
assign fifo_addr = fifo_out[39:16];

// Commands

typedef enum int unsigned {NOP, BST, READ, READ_AUTO, WRITE, WRITE_AUTO, ACT, PRE, PALL, REF, SELF, MRS} Commands;
Commands command;

// Output address calculation & control

Commands command_reg[CAS + 1], command_delayed;
assign command_reg[0] = command;
assign command_delayed = command_reg[CAS];

logic [23:0] addr_reg[CAS + 1], addr_delayed;
assign addr_reg[0] = fifo_addr;
assign addr_delayed = addr_reg[CAS];
logic [1:0] ba_delayed;
logic [12:0] row_delayed;
logic [8:0] column_delayed;
assign {ba_delayed, row_delayed, column_delayed} = addr_reg[CAS - 1];

genvar i;
generate
	for (i = 0; i < CAS; i++) begin: gen_delay
		always_ff @(posedge clk, negedge n_reset)
			if (~n_reset) begin
				command_reg[i + 1] <= NOP;
				addr_reg[i + 1] <= 24'h0;
			end else begin
				command_reg[i + 1] <= command_reg[i];
				addr_reg[i + 1] <= addr_reg[i];
			end
	end
endgenerate

struct {
	logic active;
	logic [12:0] row;
	logic [3:0] precnt, actcnt, rwcnt;
} bank[4];

// Bank specific command delay counter

generate
	for (i = 0; i < 4; i++) begin: gen_bankcnt
		logic [3:0] precnt, precnt_next, actcnt, actcnt_next, rwcnt, rwcnt_next;
		assign precnt = bank[i].precnt, actcnt = bank[i].actcnt, rwcnt = bank[i].rwcnt;
		
		always_ff @(posedge clk, negedge n_reset)
			if (~n_reset) begin
				bank[i].precnt <= 4'h0;
				bank[i].actcnt <= 4'h0;
				bank[i].rwcnt <= 4'h0;
			end else begin
				bank[i].precnt <= precnt_next;
				bank[i].actcnt <= actcnt_next;
				bank[i].rwcnt <= rwcnt_next;
			end
		
		always_comb
		begin
			precnt_next = precnt != 4'h0 ? precnt - 4'h1 : 4'h0;
			actcnt_next = actcnt != 4'h0 ? actcnt - 4'h1 : 4'h0;
			rwcnt_next = rwcnt != 4'h0 ? rwcnt - 4'h1 : 4'h0;
			if (fifo_ba == i) begin
				case (command)
				ACT: begin
					precnt_next = TRAS - 1;
					actcnt_next = TRC - 1;
					rwcnt_next = TRCD - 1;
				end
				PRE: begin
					precnt_next = 4'h0;
					actcnt_next = TRP - 1;
				end
				endcase
			end
		end
	end
endgenerate

// Bank specific row address update for reading

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		for (int i = 0; i < 4; i++) begin
			bank[i].active = 1'b0;
			bank[i].row <= 13'h0;
		end
	end else begin
		case (command)
		ACT: begin
			bank[fifo_ba].active <= 1'b1;
			bank[fifo_ba].row <= fifo_row;
		end
		READ_AUTO,
		WRITE_AUTO,
		PRE: bank[fifo_ba].active <= 1'b0;
		PALL:
			for (int i = 0; i < 4; i++)
				bank[i].active <= 1'b0;
		endcase
	end

always_ff @(posedge DRAM_CLK, negedge n_reset)
	if (~n_reset) begin
		addr_out <= 24'h0;
		data_out <= 16'h0;
		rdy_out <= 1'b0;
	end else begin
		addr_out <= addr_delayed;
		data_out <= DRAM_DQ;
		rdy_out <= command_delayed == READ;
	end

// SDRAM tri-state data bus control

logic dram_we;
logic [15:0] dram_data;
assign DRAM_DQ = dram_we ? dram_data : 16'bz;
assign dram_we = 1'b0;
assign dram_data = 16'h0;

// Command control logic

always_comb
begin
	DRAM_CKE = 1'b0;
	DRAM_RAS_N = 1'b1;
	DRAM_CAS_N = 1'b1;
	DRAM_WE_N = 1'b1;
	DRAM_BA = 2'h0;
	DRAM_ADDR = 13'h0;
	DRAM_DQM = 2'b11;
	rdack = 1'b0;
	case (command)
	NOP: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b1;
		DRAM_CAS_N = 1'b1;
		DRAM_WE_N = 1'b1;
	end
	PALL: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b1;
		DRAM_WE_N = 1'b0;
		DRAM_ADDR[10] = 1'b1;
	end
	REF: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b1;
	end
	MRS: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b0;
		// Write burst, sequential, length = 2x16bit
		{DRAM_BA, DRAM_ADDR} = {5'b00000, 1'b0, 2'b00, CAS, 1'b0, BURST};
	end
	PRE: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b1;
		DRAM_WE_N = 1'b0;
		{DRAM_BA, DRAM_ADDR[10]} = {fifo_ba, 1'b0};
	end
	ACT: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b1;
		DRAM_WE_N = 1'b1;
		{DRAM_BA, DRAM_ADDR} = {fifo_ba, fifo_row};
	end
	READ: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b1;
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b1;
		DRAM_BA = fifo_ba;
		DRAM_ADDR[10] = 1'b0;
		DRAM_ADDR[8:0] = fifo_column;
		rdack = 1'b1;
	end
	endcase
end

// Initialisation, refresh states and counter

enum int unsigned {Reset, Init, InitPALL, InitREF1, InitREF2, Active, Precharge, Refresh} state, state_next;
logic [15:0] cnt, cnt_load;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		state <= Reset;
		cnt <= 16'h0;
	end else if (cnt == 16'h0) begin
		state <= state_next;
		cnt <= cnt_load;
	end else
		cnt <= cnt - 16'h1;

// Command delay counter

logic [2:0] delay, delay_load;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		delay <= 3'h0;
	else if (delay == 3'h0)
		delay <= delay_load;
	else
		delay <= delay - 3'h1;

// Initialise mode register

logic mode;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		mode <= 1'b0;
	else if (command == MRS)
		mode <= 1'b1;

// Next state logic

logic execute;
always_comb
begin
	state_next = state;
	cnt_load = 16'h0;
	command = NOP;
	delay_load = 3'h0;
	execute = 1'b0;
	case (state)
	Reset: begin
		state_next = Init;
		cnt_load = TINIT - 1;
		command = NOP;
	end
	Init: begin
		state_next = InitPALL;
		cnt_load = TRP - 1;
		command = cnt == 16'h0 ? PALL : NOP;
	end
	InitPALL: begin
		state_next = Precharge;
		cnt_load = TRC - 1;
		command = cnt == 16'h0 ? REF : NOP;
	end
	Precharge: begin
		state_next = Refresh;
		cnt_load = TRC - 1;
		command = cnt == 16'h0 ? REF : NOP;
	end
	Refresh: begin
		state_next = Active;
		cnt_load = TREFC - 1 - TRP - TRC;
		execute = cnt == 16'h0;
	end
	Active: begin
		state_next = Precharge;
		cnt_load = TRP - 1;
		if (cnt == 16'h0)
			command = PALL;
		else
			execute = 1'b1;
	end
	default: begin
		state_next = Active;
		cnt_load = TREFC - 1;
		command = cnt == 16'h0 ? REF : NOP;
	end
	endcase
	
	if (execute && delay == 3'h0) begin
		if (~mode) begin
			command = MRS;
			delay_load = TMRD - 1;
		end else if (~empty) begin
			if (~bank[fifo_ba].active) begin
				if (bank[fifo_ba].actcnt == 4'h0 && cnt >= TRAS)
					command = ACT;
			end else if (bank[fifo_ba].row != fifo_row) begin
				if (bank[fifo_ba].precnt == 4'h0)
					command = PRE;
			end else begin
				if (bank[fifo_ba].rwcnt == 4'h0)
					command = fifo_we ? WRITE : READ;
			end
		end
	end
end
	
endmodule
