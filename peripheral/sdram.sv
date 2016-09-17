module sdram #(parameter logic [2:0] CAS = 3, BURST = 3'b001,
	int TINIT = 14300, TREFC = 1117, TRC = 9, TRAS = 6, TRP = 3, TMRD = 2, TRCD = 3) (
	input logic n_reset, clk, en,
	
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ,
	
	input logic [23:0] addr_in,
	input logic [15:0] data_in,
	input logic we, rd,
	
	output logic [23:0] addr_out,
	output logic [15:0] data_out,
	output logic rdy
);

assign DRAM_CLK = ~clk;
assign DRAM_CS_N = ~en;

// Input synchronous FIFO

// Output address calculation & control

logic we_out;
logic [15:0] data_out;
assign data = we_out ? data_out : 16'bz;
always_ff @(posedge DRAM_CLK, negedge n_reset)
	if (~n_reset) begin
		rdy <= 1'b0;
		data_out <= 16'h0;
	end else begin
		rdy <= we_out;
		data_out <= DRAM_DQ;
	end

logic dram_we;
logic [15:0] dram_data;
assign DRAM_DQ = dram_we ? dram_data : 16'bz;
assign dram_we = 1'b0;
assign dram_data = 16'h0;

enum int unsigned {NOP, BST, READ, READ_AUTO, WRITE, WRITE_AUTO, ACT, PRE, PALL, REF, SELF, MRS} command;
always_comb
begin
	DRAM_CKE = 1'b0;
	DRAM_RAS_N = 1'b1;
	DRAM_CAS_N = 1'b1;
	DRAM_WE_N = 1'b1;
	DRAM_BA = 2'h0;
	DRAM_ADDR = 13'h0;
	DRAM_DQM = 2'b11;
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
	endcase
end

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

logic [2:0] delay, delay_load;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		delay <= 3'h0;
	else if (delay == 3'h0)
		delay <= delay_load;
	else
		delay <= delay - 3'h1;

enum int unsigned {OP_IDLE, OP_MODE, OP_ACTIVE, OP_READ, OP_WRITE, OP_PRECHARGE} op, op_next;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		op <= OP_MODE;
	else
		op <= op_next;

logic execute;
always_comb
begin
	state_next = state;
	cnt_load = 16'h0;
	command = NOP;
	delay_load = 3'h0;
	execute = 1'b0;
	we_out = 1'b0;
	op_next = op;
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
		if (op == OP_MODE) begin
			command = MRS;
			delay_load = TMRD - 1;
			op_next = OP_IDLE;
		end
		if (rd) begin
			case (op)
			OP_ACTIVE: begin
				command = ACT;
				delay_load = TRCD - 1;
				op_next = OP_READ;
			end
			OP_READ: begin
				command = READ;
				delay_load = CAS - 1;
				op_next = OP_PRECHARGE;
			end
			OP_PRECHARGE: begin
				command = PALL;
				delay_load = TRP - 1;
				op_next = OP_IDLE;
				we_out = 1'b1;
			end
			default: op_next = OP_ACTIVE;
			endcase
		end
	end
end
	
endmodule
