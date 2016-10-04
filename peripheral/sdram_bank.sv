module sdram_bank #(parameter TRC, TRAS, TRP, TRCD, TDPL) (
	input logic n_reset, clk, clkSDRAM, sel,
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
	end else begin
		if (sel) begin
			active <= (active | cmd_act) & ~cmd_pre;
			if (cmd_act)
				row <= cmd_row;
		end
	end

// Bank specific command delay counter
logic [3:0] precnt, actcnt, rwcnt;
assign pre = precnt == 4'h0;
assign act = actcnt == 4'h0;
assign rw = rwcnt == 4'h0;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		precnt <= 0;
	else if (sel & cmd_act)
		precnt <= TRAS - 1;
	else if ((sel & cmd_write) && precnt > TDPL)
		precnt <= TDPL - 1;
	else if (~clkSDRAM && precnt != 0)
		precnt <= precnt - 1;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		actcnt <= 0;
	else if (sel & cmd_act)
		actcnt <= TRC - 1;
	else if (sel & cmd_pre)
		actcnt <= TRP - 1;
	else if (~clkSDRAM && actcnt != 0)
		actcnt <= actcnt - 1;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		rwcnt <= 0;
	else if (sel & cmd_act)
		rwcnt <= TRCD - 1;
	else if (~clkSDRAM && rwcnt != 0)
		rwcnt <= rwcnt - 1;

endmodule
