module tft #(
	// Address bus size, data bus size
	parameter AN = 24, DN = 16, BURST, BASE,
	// VT & HT: Sync width, back porch, display, front porch
	int HN, logic [HN - 1:0] HT[4],
	int VN, logic [VN - 1:0] VT[4]
) (
	input logic clkSYS, clkTFT, n_reset,

	// Memory interface
	input logic [DN - 1:0] mem_data,
	input logic mem_valid,

	output logic [AN - 1:0] req_addr,
	output logic req,
	input logic req_ack,

	// Hardware interface
	output logic disp, de, dclk, vsync, hsync,
	output logic [23:0] out,

	// Debugging signals
	output logic [5:0] level,
	output logic empty, full
);

// FIFO buffer
logic [15:0] fifo;
assign out = {fifo[15:11], 3'h0, fifo[10:5], 2'h0, fifo[4:0], 3'h0};

logic aclr, rdreq, wrreq;
tft_fifo fifo0 (.aclr(aclr), .data(mem_data),
	.rdclk(clkTFT), .rdreq(rdreq), .q(fifo), .rdempty(empty),
	.wrclk(clkSYS), .wrreq(wrreq), .wrfull(full), .wrusedw(level));

// Memory request
always_ff @(posedge clkSYS, posedge aclr)
	if (aclr)
		req_addr <= BASE;
	else if (req_ack)
		req_addr <= req_addr + BURST;

logic [4:0] empty_req;
logic [2:0] empty_level;
always_ff @(posedge clkTFT, posedge aclr)
	if (aclr) begin
		empty_req[0] <= 1'b0;
		empty_level <= 3'h0;
	end else if (rdreq) begin
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
always_ff @(posedge clkSYS, posedge aclr)
	if (aclr)
		fill_level <= 5'h0;
	else if (req_ack) begin
		if (!empty_req[4])
			fill_level <= fill_level + BURST;
	end else if (empty_req[4])
		fill_level <= fill_level - BURST;

always_ff @(posedge clkSYS, posedge aclr)
	if (aclr)
		req <= 1'b0;
	else if (fill_level[5:4] != 2'b11)
		req <= 1'b1;
	else if (req_ack)
		req <= 1'b0;

assign wrreq = mem_valid;

// Hardware logics
assign dclk = clkTFT;
assign disp = n_reset;
assign de = 1'b0;

// Horizontal control
logic [HN - 1:0] hcnt;
logic [1:0] hstate;
logic _hsync, htick, hblank;

always_ff @(posedge clkTFT, negedge n_reset)
	if (~n_reset) begin
		hcnt <= {HN{1'b0}};
		htick <= 1'b0;
	end else if (hcnt == {HN{1'b0}}) begin
		hcnt <= HT[hstate];
		htick <= 1'b1;
	end else begin
		hcnt <= hcnt + {HN{1'b1}};
		htick <= 1'b0;
	end

always_ff @(posedge htick, negedge n_reset)
	if (~n_reset) begin
		hstate <= 2'h0;
		_hsync <= 1'b0;
		hblank <= 1'b1;
		rdreq <= 1'b0;
	end else begin
		hstate <= hstate + 2'h1;
		_hsync <= hstate != 2'h0;
		hblank <= hstate != 2'h2;
		rdreq <= hstate == 2'h2 && ~aclr && ~empty;
	end

always_ff @(posedge clkTFT)
	hsync <= _hsync;

// Vertical control
logic [VN - 1:0] vcnt;
logic [1:0] vstate;
logic vtick, vblank;
assign aclr = vblank;

always_ff @(posedge hsync, negedge n_reset)
	if (~n_reset) begin
		vcnt <= {VN{1'b0}};
		vtick <= 1'b0;
	end else if (vcnt == {VN{1'b0}}) begin
		vcnt <= VT[vstate];
		vtick <= 1'b1;
	end else begin
		vcnt <= vcnt + {VN{1'b1}};
		vtick <= 1'b0;
	end

always_ff @(posedge vtick, negedge n_reset)
	if (~n_reset) begin
		vstate <= 2'h0;
		vsync <= 1'b0;
		vblank <= 1'b1;
	end else begin
		vstate <= vstate + 2'h1;
		vsync <= vstate != 2'h0;
		vblank <= vstate != 2'h2;
	end

endmodule
