module tft_fb #(
	// Address bus size, data bus size
	parameter AN = 24, DN = 16, BURST, BASE
) (
	input logic clkSYS, clkTFT, n_reset,

	// Memory interface
	output logic [AN - 1:0] addr,
	output logic req,
	input logic ack,

	input logic [DN - 1:0] mem,
	input logic valid,

	// TFT FIFO interface
	output logic [15:0] tft_fifo,
	output logic tft_wrreq,
	input logic tft_rdreq,

	// TFT signals
	input logic tft_vblank
);

assign tft_fifo = mem;

logic [1:0] clr;
always_ff @(posedge clkSYS)
	clr <= {clr[0], tft_vblank};

// Memory request
logic [AN - 1:0] addrn;
always_ff @(posedge clkSYS)
	addrn <= addr + BURST;
always_ff @(posedge clkSYS)
	if (clr[1])
		addr <= BASE;
	else if (ack)
		addr <= addrn;

logic [4:0] empty_req;
logic [2:0] empty_level;
always_ff @(posedge clkTFT)
	if (clr[1]) begin
		empty_req[0] <= 1'b0;
		empty_level <= 3'h0;
	end else if (tft_rdreq) begin
		empty_level <= empty_level + 3'h1;
		empty_req[0] <= empty_level == 3'h7;
	end else
		empty_req[0] <= 1'b0;

always_ff @(posedge clkSYS)
begin
	empty_req[3:1] <= empty_req[2:0];
	empty_req[4] <= empty_req[2] & ~empty_req[3];
end

logic [5:0] fill_level;
always_ff @(posedge clkSYS)
	if (clr[1])
		fill_level <= 0;
	else if (ack) begin
		if (!empty_req[4])
			fill_level <= fill_level + BURST;
	end else if (empty_req[4])
		fill_level <= fill_level - BURST;

always_ff @(posedge clkSYS)
	if (clr[1])
		req <= 1'b0;
	else if (fill_level[5:4] != 2'b11)
		req <= 1'b1;
	else if (ack)
		req <= 1'b0;

assign tft_wrreq = valid;

endmodule
