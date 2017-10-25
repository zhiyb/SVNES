module clock_delayed #(parameter CN, DN) (
	input logic clk, clkRef, n_reset,
	input logic delay,
	output logic clkout
);

logic [2:0] cref;
always_ff @(posedge clk)
	cref <= {cref[1:0], clkRef};

logic cref_rise;
always_ff @(posedge clk)
	cref_rise <= cref[1] & ~cref[2];

logic delay_latch;
always_ff @(posedge clk)
	delay_latch <= delay;

logic dir;
logic [CN - 1:0] ccnt;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		ccnt <= 0;
	else if (~dir & delay_latch) begin
		ccnt <= 0;
	end else if (dir) begin
		if (ccnt != 0)
			ccnt <= ccnt - 1;
	end else begin
		if (ccnt != {CN{1'b1}})
			ccnt <= ccnt + 1;
	end

logic top, bottom;
always_ff @(posedge clk)
begin
	top <= ccnt == {CN{1'b1}};
	bottom <= ccnt == 0;
end

logic rise;
always_ff @(posedge clk)
	if (top & dir & ~rise)
		rise <= 1'b1;
	else
		rise <= 1'b0;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		clkout <= 1'b0;
	else if (rise)
		clkout <= 1'b1;
	else if (bottom)
		clkout <= 1'b0;

logic [DN - 1:0] dcnt;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		dcnt <= 0;
	else if (cref_rise)
		dcnt <= dcnt + 1;
	else if (rise)
		dcnt <= dcnt - 1;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		dir <= 1'b0;
	else if (top && dcnt != 0)
		dir <= 1'b1;
	else if (bottom && ~delay_latch)
		dir <= 1'b0;

endmodule
