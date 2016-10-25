module tft_fetch (
	input logic n_reset,
	// TFT interface
	input logic clkTFT, vblank, hblank,
	output logic [23:0] out,
	// High speed data interface
	input logic clk,
	output logic req, underrun,
	input logic rdy, ifrdy,
	output logic [23:0] addr,
	input logic [15:0] data
);

// A pixel rendered
logic clkTFT_flag, clkTFT_reg, clkTFT_delayed;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		clkTFT_reg <= 1'b0;
		clkTFT_delayed <= 1'b1;
	end else begin
		clkTFT_reg <= ~clkTFT;
		clkTFT_delayed <= ~clkTFT_reg;
	end

assign clkTFT_flag = clkTFT_reg & clkTFT_delayed;

logic update;
assign update = clkTFT_flag & ~vblank & ~hblank;
/*always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		update <= 1'b0;
	else
		update <= clkTFT_flag & ~vblank & ~hblank;*/

// A new frame started
logic reset;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		reset <= 1'b1;
	else
		reset <= vblank;

// FIFO controller
logic empty, full, overrun;
logic [5:0] head, tail;
fifo_sync #(.DEPTH_N(6)) fifo0 (.flush(reset),
	.wrreq(ifrdy), .rdack(update), .*);

// FIFO level counter
logic [5:0] level;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		level <= 0;
	else if (reset)
		level <= 0;
	else if (req & rdy)
		level <= level + 8 - (update ? 1 : 0);
	else if (update && level != 0)
		level <= level - 1;

// Request generator
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		req <= 1'b0;
	else
		req <= ~reset & ~(level[5] & level[4]);

// Address counter
assign addr[23:20] = 4'hf;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		addr[19:0] <= 20'h0;
	else if (reset)
		addr[19:0] <= 20'h0;
	else if (req & rdy)
		addr[19:0] <= addr[19:0] + 20'h8;

// FIFO data RAM
logic [15:0] fifo;
ramdual64x16 ram0 (.aclr(~n_reset), .clock(clk), .data(data), .q(fifo),
	.rdaddress(tail), .wraddress(head), .wren(ifrdy));

// Pixel output
always_ff @(posedge clkTFT, negedge n_reset)
	if (~n_reset)
		out <= 24'h0;
	else
		out <= {fifo[15:11], 3'h0, fifo[10:5], 2'h0, fifo[4:0], 3'h0};
//assign out = {fifo[15:11], 3'h0, fifo[10:5], 2'h0, fifo[4:0], 3'h0};

endmodule
