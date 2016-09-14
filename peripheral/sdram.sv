module sdram #(parameter logic [2:0] CS = 3,
	int TINIT = 14300, TRC = 9, TRAS = 6, TRP = 3, TMRD = 2) (
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
	DRAM_DQM = 2'h0;
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
		// Burst, length = 2x16bit
		{DRAM_BA, DRAM_ADDR} = {5'b00000, 1'b0, 2'b00, CS, 1'b0, 3'b001};
	end
	endcase
end

enum {Reset, Init, InitPALL, InitREF1, InitREF2, InitMode} state;
logic [15:0] cnt;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		state <= Reset;
		cnt <= 16'h0;
		command <= NOP;
	end else if (cnt == 16'h0)
		case (state)
		Reset: begin
			state <= Init;
			cnt <= TINIT - 1;
			command <= NOP;
		end
		Init: begin
			state <= InitPALL;
			cnt <= TRP - 1;
			command <= PALL;
		end
		InitPALL: begin
			state <= InitREF1;
			cnt <= TRC - 1;
			command <= REF;
		end
		InitREF1: begin
			state <= InitREF2;
			cnt <= TRC - 1;
			command <= REF;
		end
		InitREF2: begin
			state <= InitMode;
			cnt <= TMRD - 1;
			command <= MODE;
		end
		default: begin
			state <= Reset;
			cnt <= 16'h0;
			command <= NOP;
		end
		endcase
	else begin
		cnt <= cnt - 16'h1;
		command <= NOP;
	end

endmodule
