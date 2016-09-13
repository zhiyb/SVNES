module sdram #(parameter CS = 3, INIT = 14300) (
	input logic n_reset, clk, en,
	output logic [12:0] DRAM_ADDR,
	output logic [1:0] DRAM_BA, DRAM_DQM,
	output logic DRAM_CKE, DRAM_CLK,
	output logic DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N,
	inout wire [15:0] DRAM_DQ
);

assign DRAM_CLK = ~clk;
assign DRAM_CS_N = ~en;

enum {NOP} command;
always_comb
begin
	DRAM_CKE = 1'b0;
	case (command)
	NOP: begin
		DRAM_CKE = 1'b1;
		DRAM_RAS_N = 1'b1;
		DRAM_CAS_N = 1'b1;
		DRAM_WE_N = 1'b1;
	end
	endcase
end

enum {Reset, Init} state;
logic [15:0] cnt;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		state <= Reset;
		cnt <= 16'h0;
	end else if (cnt == 16'h0)
		case (state)
		Reset: begin
			state <= Init;
			cnt <= INIT;
		end
		Init: state <= Init;
		default: state <= Init;
		endcase
	else
		cnt <= cnt - 16'h1;

endmodule
