module sdram #(parameter logic [2:0] CS = 3, BURST = 3'b001,
	int TINIT = 14300, TREFC = 1117, TRC = 9, TRAS = 6, TRP = 3, TMRD = 2) (
	input logic n_reset, clk, en,
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ
);

assign DRAM_CLK = ~clk;
assign DRAM_CS_N = ~en;

logic we;
logic [15:0] data;
assign DRAM_DQ = we ? data : 16'bz;
assign we = 1'b0;

enum {NOP, PALL, REF, MODE} command;
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
	MODE: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b0;
		// Write burst, sequential, length = 2x16bit
		{DRAM_BA, DRAM_ADDR} = {5'b00000, 1'b0, 2'b00, CS, 1'b0, BURST};
	end
	endcase
end

enum {Reset, Init, InitPALL, InitREF1, InitREF2, Active, Precharge, Refresh} state, state_next;
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

logic mode;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		mode <= 1'b0;
	else
		case (command)
		MODE: mode <= 1'b1;
		endcase

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
	
	if (execute)
		if (~mode)
			command = MODE;
end
	
endmodule
