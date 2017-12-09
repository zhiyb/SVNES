module tft #(
	// VT & HT: Sync width, back porch, display, front porch
	parameter int HN, logic [HN - 1:0] HT[4],
	int VN, logic [VN - 1:0] VT[4]
) (
	input logic clkSYS, clkTFT, n_reset,

	// FIFO interface
	input logic [15:0] tft_fifo,
	input logic tft_wrreq,
	output logic tft_rdreq,

	// TFT signals
	output logic tft_hblank, tft_vblank,

	// Hardware IO
	output logic disp, de, dclk, vsync, hsync,
	output logic [23:0] out,

	// Status
	output logic [5:0] level,
	output logic empty, full
);

// FIFO buffer
logic [15:0] fifo;
assign out = {fifo[15:11], 3'h0, fifo[10:5], 2'h0, fifo[4:0], 3'h0};

logic aclr, rdreq, wrreq;
assign wrreq = tft_wrreq;
assign tft_rdreq = rdreq;
tft_fifo fifo0 (.aclr(aclr), .data(tft_fifo),
	.rdclk(clkTFT), .rdreq(rdreq), .q(fifo), .rdempty(empty),
	.wrclk(clkSYS), .wrreq(wrreq), .wrfull(full), .wrusedw(level));

// Hardware logics
assign dclk = clkTFT;
assign disp = n_reset;
assign de = 1'b0;

// Horizontal control
logic [HN - 1:0] hcnt;
logic [1:0] hstate;
logic _hsync, htick, hblank;
assign tft_hblank = hblank;

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
assign tft_vblank = vblank;

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
