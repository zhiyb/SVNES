// Rectangular memory fill
module rectfill #(
	// Address bus size, data bus size
	parameter AN = 24, DN = 16, BASE,
	// x-counter bits, y-counter btis, line size
	XN = 8, YN = 8, LS = 480,
	// x-offset, y-offset, x-length, y-length, line size
	XOFF = 0, YOFF = 0, XLEN = 16, YLEN = 16
) (
	input logic clkSYS, n_reset,

	// Memory interface
	output logic [AN - 1:0] addr,
	output logic [DN - 1:0] data,
	output logic req, wr,
	input logic ack,

	// Control
	input logic start,
	output logic active
);

// Counters

logic update;
logic [XN - 1:0] x;
logic [YN - 1:0] y;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		x <= 0;
	end else if (update) begin
		if (x == 0)
			x <= XLEN - 1;
		else
			x <= x - 1;
	end

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		y <= 0;
	end else if (update && x == 0) begin
		if (y == 0)
			y <= YLEN - 1;
		else
			y <= y - 1;
	end

logic xend, yend;
always_ff @(posedge clkSYS)
begin
	xend <= x == 0;
	yend <= y == 0;
end

// Memory access

logic lfsr_fb;
logic [17:0] lfsr;
lfsr #(18, 0) (~active, n_reset, lfsr_fb, lfsr);
assign lfsr_fb = ~lfsr[17] ^ lfsr[10];

assign data = lfsr[17:2];
assign wr = 1'b1;

logic [1:0] updated;
always_ff @(posedge clkSYS)
	updated <= {updated[0], update};

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		active <= 1'b0;
	else if (start)
		active <= 1'b1;
	else if (update & yend & xend)
		active <= 1'b0;

always_ff @(posedge clkSYS)
	update <= ack;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		req <= 1'b0;
	else if (req)
		req <= ~ack;
	else 
		req <= active & ~update;

// Address generation

localparam RELOAD = BASE + YOFF * LS + XOFF;

logic [AN - 1:0] yaddr;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		yaddr <= RELOAD;
	else if (yend)
		yaddr <= RELOAD;
	else if (xend & updated[1])
		yaddr <= yaddr + LS;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		addr <= RELOAD;
	else if (update) begin
		if (xend)
			addr <= yaddr;
		else
			addr <= addr + 1;
	end

endmodule
