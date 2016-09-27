// VT & HT:	Sync width, back porch, display, front porch
module tft #(parameter HN, VN, logic [HN - 1:0] HT[4], logic [VN - 1:0] VT[4]) (
	input logic n_reset, pixclk, en,
	output logic dclk, hsync, vsync, disp, de,
	output logic hblank, vblank,
	output logic [HN - 1:0] x,
	output logic [VN - 1:0] y
);

assign dclk = pixclk;
assign disp = en;

logic [HN - 1:0] hcnt;
logic [VN - 1:0] vcnt;
logic [1:0] hstate, vstate;
logic htick, vtick, hs, vs;

// Horizontal timing counter
always_ff @(posedge pixclk, negedge n_reset)
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

// x-coordinate counter
always_ff @(posedge pixclk, negedge n_reset)
	if (~n_reset)
		x <= {HN{1'b0}};
	else if (hblank)
		x <= {HN{1'b0}};
	else
		x <= x + 1;

// Horizontal signal states
always_ff @(posedge htick, negedge n_reset)
	if (~n_reset) begin
		hstate <= 2'h0;
		hs <= 1'b0;
	end else begin
		hstate <= hstate + 2'h1;
		hs <= hstate == 2'h0;
	end

assign hblank = hstate != 2'h3;
assign hsync = ~hs;
assign de = 1'b0;

// Vertical timing counter
always_ff @(posedge hs, negedge n_reset)
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

// y-coordinate counter
always_ff @(posedge hs, negedge n_reset)
	if (~n_reset)
		y <= {VN{1'b0}};
	else if (vblank)
		y <= {VN{1'b0}};
	else
		y <= y + 1;

// Vertical signal states
always_ff @(posedge vtick, negedge n_reset)
	if (~n_reset) begin
		vstate <= 2'h0;
		vs <= 1'b0;
	end else begin
		vstate <= vstate + 2'h1;
		vs <= vstate == 2'h0;
	end

assign vblank = vstate != 2'h3;
assign vsync = ~vs;

endmodule
