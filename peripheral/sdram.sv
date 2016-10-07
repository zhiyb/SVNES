module sdram #(parameter logic [2:0] CAS = 2, BURST = 3'b010,
	int TRC = 8, TRAS = 6, TRP = CAS, TMRD = 2, TRCD = CAS, TDPL = 2,
	int TINIT = 13300, TREFC = 1039, TWAIT = 6 /* max(TRAS, 2 ** BURST, TDPL) */) (
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

// Input registers
logic [40:0] reg_out;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		reg_out <= 41'h0;
	else if (rdy)
		reg_out <= {we, addr_in, data_in};

logic reg_we;
logic [1:0] reg_ba;
logic [12:0] reg_row;
logic [8:0] reg_column;
logic [15:0] reg_data;
assign {reg_we, reg_ba, reg_row, reg_column, reg_data} = reg_out;
logic [23:0] reg_addr;
assign reg_addr = reg_out[39:16];

logic [40:0] fifo_out;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		fifo_out <= 41'h0;
	else
		fifo_out <= reg_out;

logic fifo_we;
logic [1:0] fifo_ba;
logic [12:0] fifo_row;
logic [8:0] fifo_column;
logic [15:0] fifo_data;
assign {fifo_we, fifo_ba, fifo_row, fifo_column, fifo_data} = fifo_out;
logic [23:0] fifo_addr;
assign fifo_addr = fifo_out[39:16];

// Commands
typedef enum int unsigned {NOP, BST, READ, /*READ_AUTO,*/ WRITE, /*WRITE_AUTO,*/ ACT, PRE, PALL, REF, SELF, MRS} Commands;
Commands command, command_state, command_execute;

// Bank states
struct {
	logic sel, active, match;
	logic pre, act, rw;
} bank[4];

always_comb
begin
	for (int i = 0; i < 4; i++)
		bank[i].sel = command == PALL;
	bank[reg_ba].sel = 1'b1;
end

genvar i;
generate
	for (i = 0; i < 4; i++) begin: gen_bank
		sdram_bank #(.TRC(TRC), .TRAS(TRAS), .TRP(TRP), .TRCD(TRCD), .TDPL(TDPL))
			bank0 (.sel(bank[i].sel),
			.cmd_pre(command_execute == PRE || command == PALL),
			.cmd_act(command_execute == ACT), .cmd_write(command_execute == WRITE),
			.cmd_row(reg_row), .active(bank[i].active), .match(bank[i].match),
			.pre(bank[i].pre), .act(bank[i].act), .rw(bank[i].rw), .*);
	end
endgenerate

// Burst counter
logic [2 ** BURST + CAS:0] burst;
logic burst_wait;
assign burst_wait = burst[2 + CAS];
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		burst <= 0;
	else begin
		if (command == READ)
			burst[2 ** BURST + CAS -: 2 ** BURST - 1] <= {2 ** BURST - 1{1'b1}};
		else
			burst[2 ** BURST + CAS -: 2 ** BURST - 1] <= {1'b0, burst[2 ** BURST + CAS -: 2 ** BURST - 2]};
		burst[CAS + 1:0] <= burst[CAS + 2:1];
	end

// Data output address calculation
logic [23:0] addr_reg[CAS + 2], addr_delayed;
assign addr_reg[0] = fifo_addr;
assign addr_delayed = addr_reg[CAS + 1];

generate
	for (i = 0; i < CAS + 1; i++) begin: gen_addr
		always_ff @(posedge clk, negedge n_reset)
			if (~n_reset)
				addr_reg[i + 1] <= 24'h0;
			else
				addr_reg[i + 1] <= addr_reg[i];
	end
endgenerate

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		addr_out <= 24'h0;
	else begin
		if (burst[1]) begin
			addr_out[23:BURST] <= addr_out[23:BURST];
			addr_out[BURST - 1:0] <= addr_out[BURST - 1:0] + 1;
		end else begin
			addr_out[23:BURST] <= addr_delayed[23:BURST];
			addr_out[BURST - 1:0] <= addr_delayed[BURST - 1:0];
		end
	end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		data_out <= 16'h0;
	else
		data_out <= DRAM_DQ;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		rdy_out <= 1'b0;
	else
		rdy_out <= burst[2] | burst[1];

// Write delay counter
logic [3:0] wrdelay;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		wrdelay <= 3'h0;
	else if (command == READ)
		wrdelay <= CAS + (2 ** BURST) + 2 - 1;
	else if (wrdelay != 0)
		wrdelay <= wrdelay - 1;

// State delay counter
logic [15:0] cnt, cnt_load;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		cnt <= 0;
	else begin
		if (cnt == 0)
			cnt <= cnt_load;
		else
			cnt <= cnt - 1;
	end

logic update;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		update <= 1'b0;
	else
		update <= cnt == 0;

// Initialisation, refresh and active states
enum int unsigned {Reset, Init, InitPALL, Execute, Active, Precharge, Refresh} state, state_next;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		state <= Reset;
	else if (update)
		state <= state_next;

// Command to execute
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		command <= NOP;
	else begin
		if (update)
			command <= command_state;
		else if (state == Execute)
			command <= command_execute;
		else
			command <= NOP;
	end

// Command state machine
enum int unsigned {CIdle, CRegistered, CPrecharge, CActive, CExecute} cstate;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		cstate <= CIdle;
	else if (update || state != Execute || burst_wait) begin
		if (req || cstate != CIdle)
			cstate <= CRegistered;
	end else
		case (cstate)
		CIdle:
			if (req)
				cstate <= CRegistered;
		CRegistered: begin
			if (~bank[reg_ba].active)
				cstate <= CActive;
			else if (~bank[reg_ba].match)
				cstate <= CPrecharge;
			else
				cstate <= CExecute;
		end
		CActive:
			if (command_execute == ACT)
				cstate <= CExecute;
		CPrecharge:
			if (command_execute == PRE)
				cstate <= CActive;
		CExecute:
			if (command_execute == READ || command_execute == WRITE)
				cstate <= CIdle;
		endcase

always_comb
begin
	rdy = cstate == CIdle;
	command_execute = NOP;
	case (cstate)
	CActive: begin
		if (bank[reg_ba].act)
			command_execute = ACT;
	end
	CPrecharge: begin
		if (bank[reg_ba].pre)
			command_execute = PRE;
	end
	CExecute: begin
		if (bank[reg_ba].rw) begin
			if (~reg_we)
				command_execute = READ;
			else if (wrdelay == 0)
				command_execute = WRITE;
		end
	end
	endcase
end

// Mode register
logic mode;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		mode <= 1'b1;
	else if (command == MRS)
		mode <= 1'b0;

// Next state logic
always_comb
begin
	state_next = state;
	cnt_load = 16'h0;
	command_state = NOP;
	case (state)
	Reset: begin
		state_next = Init;
		cnt_load = TINIT - 1;
	end
	Init: begin
		state_next = InitPALL;
		cnt_load = TRP - 1;
		command_state = PALL;
	end
	InitPALL: begin
		state_next = Precharge;
		cnt_load = TRC - 1;
		command_state = REF;
	end
	Precharge: begin
		state_next = Refresh;
		cnt_load = TRC - 1;
		command_state = REF;
	end
	Refresh: begin
		if (mode) begin
			cnt_load = TMRD - 1;
			command_state = MRS;
		end else begin
			state_next = Execute;
			cnt_load = TREFC - 1 - TRP - TRC - 1 - TWAIT;
		end
	end
	Execute: begin
		state_next = Active;
		cnt_load = TWAIT - 1;
	end
	Active: begin
		state_next = Precharge;
		cnt_load = TRP - 1;
		command_state = PALL;
	end
	endcase
end

// Tri-state data bus control
logic dram_we;
logic [15:0] dram_out;
assign DRAM_DQ = dram_we ? dram_out : 16'bz;

// Interface logic
assign DRAM_CLK = clk;
assign DRAM_CS_N = ~en;

logic [12:0] DRAM_ADDR_n;
logic [1:0] DRAM_BA_n, DRAM_DQM_n;
logic DRAM_CKE_n, DRAM_RAS_N_n, DRAM_CAS_N_n, DRAM_WE_N_n;
logic dram_we_n;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		DRAM_CKE <= 1'b0;
		DRAM_RAS_N <= 1'b1;
		DRAM_CAS_N <= 1'b1;
		DRAM_WE_N <= 1'b1;
		DRAM_BA <= 2'h0;
		DRAM_ADDR <= 13'h0;
		DRAM_DQM <= 2'b00;
		dram_we <= 1'b0;
		dram_out <= 16'h0;
	end else begin
		DRAM_CKE <= DRAM_CKE_n;
		DRAM_RAS_N <= DRAM_RAS_N_n;
		DRAM_CAS_N <= DRAM_CAS_N_n;
		DRAM_WE_N <= DRAM_WE_N_n;
		DRAM_BA <= DRAM_BA_n;
		DRAM_ADDR <= DRAM_ADDR_n;
		DRAM_DQM <= DRAM_DQM_n;
		dram_we <= dram_we_n;
		dram_out <= fifo_data;
	end

always_comb
begin
	DRAM_CKE_n = 1'b0;
	DRAM_RAS_N_n = 1'b1;
	DRAM_CAS_N_n = 1'b1;
	DRAM_WE_N_n = 1'b1;
	DRAM_BA_n = fifo_ba;
	DRAM_ADDR_n = 13'h0;
	DRAM_ADDR_n = fifo_row;
	DRAM_ADDR_n[8:0] = fifo_column;
	DRAM_DQM_n = 2'b00;
	dram_we_n = 1'b0;
	
	case (command)
	NOP: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b1;
		DRAM_CAS_N_n = 1'b1;
		DRAM_WE_N_n = 1'b1;
	end
	PALL: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b0;
		DRAM_CAS_N_n = 1'b1;
		DRAM_WE_N_n = 1'b0;
		DRAM_ADDR_n[10] = 1'b1;
	end
	REF: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b0;
		DRAM_CAS_N_n = 1'b0;
		DRAM_WE_N_n = 1'b1;
	end
	MRS: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b0;
		DRAM_CAS_N_n = 1'b0;
		DRAM_WE_N_n = 1'b0;
		// No write burst, sequential
		{DRAM_BA_n, DRAM_ADDR_n} = {5'b00000, 1'b1, 2'b00, CAS, 1'b0, BURST};
	end
	PRE: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b0;
		DRAM_CAS_N_n = 1'b1;
		DRAM_WE_N_n = 1'b0;
		DRAM_BA_n = fifo_ba;
		DRAM_ADDR_n[10] = 1'b0;
	end
	ACT: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b0;
		DRAM_CAS_N_n = 1'b1;
		DRAM_WE_N_n = 1'b1;
		DRAM_BA_n = fifo_ba;
		DRAM_ADDR_n = fifo_row;
	end
	READ/*,
	READ_AUTO*/: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b1;
		DRAM_CAS_N_n = 1'b0;
		DRAM_WE_N_n = 1'b1;
		DRAM_BA_n = fifo_ba;
		DRAM_ADDR_n[10] = 1'b0;//command == READ_AUTO;
		DRAM_ADDR_n[8:0] = fifo_column;
	end
	WRITE/*,
	WRITE_AUTO*/: begin
		DRAM_CKE_n = 1'b1;
		DRAM_RAS_N_n = 1'b1;
		DRAM_CAS_N_n = 1'b0;
		DRAM_WE_N_n = 1'b0;
		DRAM_BA_n = fifo_ba;
		DRAM_ADDR_n[10] = 1'b0;//command == WRITE_AUTO;
		DRAM_ADDR_n[8:0] = fifo_column;
		dram_we_n = 1'b1;
	end
	endcase
end

endmodule
