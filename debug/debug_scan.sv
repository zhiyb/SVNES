module debug_scan #(parameter DBGN = 1) (
	// Debug info scan chain
	input logic clkDebug,
	input logic dbg_load, dbg_shift,
	input logic dbg_din,
	output logic dbg_dout,
	input logic [DBGN * 8 - 1:0] dbg,
	output logic dbg_updated,
	output logic [DBGN * 8 - 1:0] dbg_out
);

logic [DBGN * 8 - 1:0] dbg_sr;
assign dbg_dout = dbg_sr[DBGN * 8 - 1];
always_ff @(posedge clkDebug)
	if (dbg_load)
		dbg_sr <= dbg;
	else if (dbg_shift)
		dbg_sr <= {dbg_sr[DBGN * 8 - 2:0], dbg_din};

always_ff @(posedge clkDebug)
begin
	dbg_updated <= dbg_load;
	if (dbg_load)
		dbg_out <= dbg_sr;
end

endmodule
