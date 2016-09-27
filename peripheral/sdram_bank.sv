module sdram_bank #(parameter TRC, TRAS, TRP, TRCD, TDPL) (
	input logic n_reset, clk, sel,
	input logic cmd_pre, cmd_act, cmd_write,
	input logic [12:0] cmd_row,
	output logic active, match,
	output logic pre, act, rw
);

// Bank specific row address update
logic [12:0] row;
assign match = cmd_row == row;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		active <= 1'b0;
		row <= 13'h0;
	end else if (sel) begin
		if (cmd_act) begin
			active <= 1'b1;
			row <= cmd_row;
		end else if (cmd_pre)
			active <= 1'b0;
	end

// Bank specific command delay counter
logic [3:0] precnt, actcnt, rwcnt;
assign pre = precnt == 4'h0;
assign act = actcnt == 4'h0;
assign rw = rwcnt == 4'h0;

logic [3:0] precnt_next, actcnt_next, rwcnt_next;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		precnt <= 4'h0;
		actcnt <= 4'h0;
		rwcnt <= 4'h0;
	end else begin
		precnt <= precnt_next;
		actcnt <= actcnt_next;
		rwcnt <= rwcnt_next;
	end

always_comb
begin
	precnt_next = precnt != 4'h0 ? precnt - 4'h1 : 4'h0;
	actcnt_next = actcnt != 4'h0 ? actcnt - 4'h1 : 4'h0;
	rwcnt_next = rwcnt != 4'h0 ? rwcnt - 4'h1 : 4'h0;
	if (sel) begin
		if (cmd_act) begin
			precnt_next = TRAS - 1;
			actcnt_next = TRC - 1;
			rwcnt_next = TRCD - 1;
		end else if (cmd_pre) begin
			actcnt_next = TRP - 1;
		end else if (cmd_write) begin
			precnt_next = precnt_next > TDPL - 1 ? precnt_next : TDPL - 1;
		end
	end
end

endmodule
