module sdram #(parameter logic [2:0] CAS = 2, BURST = 3'b000,
	int TINIT = 13300, TREFC = 1039,
	int TRC = 8, TRAS = 6, TRP = CAS, TMRD = 2, TRCD = CAS, TDPL = 2) (
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

// Input register
logic rdack, pending;
logic [40:0] reg_in, reg_out;
assign reg_in = {we, addr_in, data_in};

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		reg_out <= 41'h0;
		pending <= 1'b0;
	end else if (rdy) begin
		reg_out <= reg_in;
		pending <= req;
	end

assign rdy = rdack | ~pending;

logic reg_we;
logic [1:0] reg_ba;
logic [12:0] reg_row;
logic [8:0] reg_column;
logic [15:0] reg_data;
assign {reg_we, reg_ba, reg_row, reg_column, reg_data} = reg_out;
logic [23:0] reg_addr;
assign reg_addr = reg_out[39:16];

logic [40:0] fifo_out;
assign fifo_out = reg_out;

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
Commands command;

// Output address calculation & control
logic read_reg[CAS + 1], read_delayed;
assign read_reg[0] = command == READ;
assign read_delayed = read_reg[CAS];

logic [23:0] addr_reg[CAS + 1], addr_delayed;
assign addr_reg[0] = fifo_addr;
assign addr_delayed = addr_reg[CAS];

genvar i;
generate
	for (i = 0; i < CAS; i++) begin: gen_delay
		always_ff @(posedge clk, negedge n_reset)
			if (~n_reset) begin
				read_reg[i + 1] <= 1'b0;
				addr_reg[i + 1] <= 24'h0;
			end else begin
				read_reg[i + 1] <= read_reg[i];
				addr_reg[i + 1] <= addr_reg[i];
			end
	end
endgenerate

always_ff @(posedge DRAM_CLK, negedge n_reset)
	if (~n_reset) begin
		addr_out <= 24'h0;
		data_out <= 16'h0;
		rdy_out <= 1'b0;
	end else begin
		addr_out <= addr_delayed;
		data_out <= DRAM_DQ;
		rdy_out <= read_delayed;
	end

// Bank specific
struct {
	logic sel, active, match;
	logic pre, act, rw;
} bank[4];

generate
	for (i = 0; i < 4; i++) begin: gen_bank
		sdram_bank #(.TRC(TRC), .TRAS(TRAS), .TRP(TRP), .TRCD(TRCD), .TDPL(TDPL))
			bank0 (.sel(bank[i].sel), 
			.cmd_pre(command == PRE || command == PALL),
			.cmd_act(command == ACT), .cmd_write(command == WRITE),
			.cmd_row(fifo_row), .active(bank[i].active), .match(bank[i].match),
			.pre(bank[i].pre), .act(bank[i].act), .rw(bank[i].rw), .*);
	end
endgenerate

always_comb
begin
	for (int i = 0; i < 4; i++)
		bank[i].sel = command == PALL;
	bank[fifo_ba].sel = 1'b1;
end

// Tri-state data bus control
logic dram_we;
assign DRAM_DQ = dram_we ? fifo_data : 16'bz;

// Output control logic
always_comb
begin
	DRAM_CKE = 1'b0;
	DRAM_RAS_N = 1'b1;
	DRAM_CAS_N = 1'b1;
	DRAM_WE_N = 1'b1;
	DRAM_BA = fifo_ba;
	DRAM_ADDR = 13'h0;
	DRAM_ADDR[8:0] = fifo_column;
	DRAM_DQM = 2'b11;
	rdack = 1'b0;
	dram_we = 1'b0;
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
	READ/*,
	READ_AUTO*/: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b1;
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b1;
		DRAM_BA = fifo_ba;
		DRAM_ADDR[10] = 1'b0;//command == READ_AUTO;
		DRAM_ADDR[8:0] = fifo_column;
		rdack = 1'b1;
	end
	WRITE/*,
	WRITE_AUTO*/: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b1;
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b0;
		DRAM_BA = fifo_ba;
		DRAM_ADDR[10] = 1'b0;//command == WRITE_AUTO;
		DRAM_ADDR[8:0] = fifo_column;
		rdack = 1'b1;
		dram_we = 1'b1;
	end
	endcase
end

// Initialisation, refresh states and counter
enum int unsigned {Reset, Init, InitPALL, Execute, Active, Precharge, Refresh} state, state_next;
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
logic [2:0] wrdelay;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		wrdelay <= 3'h0;
	else if (command == READ /*|| command == READ_AUTO*/)
		wrdelay <= CAS + 2 - 1;
	else if (wrdelay != 3'h0)
		wrdelay <= wrdelay - 3'h1;

// Mode register
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
		if (mode) begin
			state_next = Refresh;
			cnt_load = TMRD - 1;
			command = cnt == 16'h0 ? MRS : NOP;
		end else begin
			state_next = Execute;
			cnt_load = TREFC - 1 - TRP - TRC - 1;
			//execute = cnt == 16'h0;
		end
	end
	Execute: begin
		state_next = Active;
		cnt_load = 16'h0;
		execute = 1'b1;
	end
	Active: begin
		state_next = Precharge;
		cnt_load = TRP - 1;
		command = PALL;
	end
	endcase
	
	if (execute & pending) begin
		if (~bank[reg_ba].active) begin
			if (bank[reg_ba].act && cnt >= TRAS)
				command = ACT;
		end else if (~bank[reg_ba].match) begin
			if (bank[reg_ba].pre)
				command = PRE;
		end else begin
			if (bank[reg_ba].rw) begin
				if (~reg_we)
					command = READ;
				else if (wrdelay == 3'h0)
					command = WRITE;
			end
		end
	end
end
	
endmodule
