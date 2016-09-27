module tft_fetch (
	input logic n_reset, clkSYS, clkTFT,
	// TFT interface
	input logic vblank, hblank,
	output logic [23:0] out,
	// Data interface
	output logic req, underrun,
	input logic rdy, ifrdy,
	output logic [23:0] addr,
	input logic [15:0] data
);

// A pixel rendered
logic clkTFT_flag, clkTFT_reg, clkTFT_delayed;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		clkTFT_reg <= 1'b0;
		clkTFT_delayed <= 1'b1;
	end else begin
		clkTFT_reg <= ~clkTFT;
		clkTFT_delayed <= ~clkTFT_reg;
	end

assign clkTFT_flag = clkTFT_reg & clkTFT_delayed;

logic update;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		update <= 1'b0;
	else
		update <= clkTFT_flag & ~vblank & ~hblank;

// A new frame started
logic reset;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		reset <= 1'b1;
	else
		reset <= vblank;

// FIFO controller
logic we;
assign we = ifrdy;
logic empty, full, overrun;
logic [4:0] head, tail;
fifo_sync #(.DEPTH_N(5)) fifo0 (.clk(clkSYS), .flush(reset),
	.wrreq(we), .rdack(update), .level(), .*);

// FIFO level counter
logic [4:0] level;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		level <= 5'h0;
	else if (reset)
		level <= 5'h0;
	else if (req & rdy)
		level <= level + 4 - (update ? 1 : 0);
	else if (update && level != 0)
		level <= level - 1'b1;

assign req = ~reset & ~level[4] & ~level[3];

// Address counter
assign addr[23:20] = 4'hf;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		addr[19:0] <= 20'h0;
	else if (reset)
		addr[19:0] <= 20'h0;
	else if (req & rdy)
		addr[19:0] <= addr[19:0] + 20'h4;

// FIFO data RAM
logic [15:0] fifo;
ramdual32x16 ram0 (.aclr(~n_reset), .clock(clkSYS), .data(data), .q(fifo),
	.rdaddress(tail), .wraddress(head), .wren(we));

// Pixel output
assign out = {fifo[15:11], 3'h0, fifo[10:5], 2'h0, fifo[4:0], 3'h0};

endmodule
