module system (
	input logic clkCPU2, clkPPU, n_reset,
	// Audio
	output logic [7:0] audio,
	// Video
	output logic [23:0] video_rgb,
	output logic video_vblank, video_hblank
);

// Clock generation
logic clk, dclk;
always_ff @(posedge clkCPU2, negedge n_reset)
	if (~n_reset) begin
		clk <= 1'b1;
		dclk <= 1'b1;
	end else begin
		clk <= ~clk;
		dclk <= clk;
	end

logic clkRAM;
always_ff @(negedge clkCPU2, negedge n_reset)
	if (~n_reset)
		clkRAM <= 1'b1;
	else
		clkRAM <= clk;

// Memory access arbiter
logic [1:0] arb_req, arb_grant, arb_rot;
assign arb_rot = 1;	// Fixed priority
arbiter #(.N(2)) arb_mem (arb_req, arb_grant, arb_rot, 2'b11, , );

// DMA

// CPU
logic reset, nmi, irq, sys_rw;
wire sys_rdy;
logic [15:0] sys_addr;
wire [7:0] sys_data;
cpu cpu0 (clk, dclk, n_reset, reset, nmi, irq,
	sys_rdy, sys_addr, sys_data, sys_rw);
assign arb_req[1] = 1'b1;

// APU
logic [15:0] apu_addr;
logic apu_rdy, apu_req, apu_irq;
logic [7:0] apu_out;
apu apu0 (clk, dclk, n_reset, sys_addr, sys_data, sys_rdy, ~sys_rw,
	apu_addr, apu_rdy, apu_req, apu_irq, apu_out);
assign apu_rdy = 1'b0;
assign irq = apu_irq;
assign audio = apu_out;
assign arb_req[0] = apu_req;

// RAM at $0000 to $2000 of size $0800 (2kB)
logic ram0sel;
assign ram0sel = (sys_addr & ~16'h1fff) == 16'h0000;
assign sys_rdy = ram0sel ? 1'b1 : 1'bz;
logic [7:0] ram0q;
ram2k ram0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[10:0]), .data(sys_data),
	.wren(ram0sel & ~sys_rw), .q(ram0q));
assign sys_data = (ram0sel & sys_rw) ? ram0q : 8'bz;

// PPU
logic ppu_nmi;
logic [13:0] ppu_addr;
wire [7:0] ppu_data;
logic ppu_rd, ppu_wr;
ppu ppu0 (clk, dclk, clkPPU, n_reset, reset, ppu_nmi,
	sys_addr, sys_data, sys_rdy, sys_rw,
	ppu_addr, ppu_data, ppu_rd, ppu_wr,
	video_rgb, video_vblank, video_hblank);
assign nmi = ppu_nmi;

// PPU pattern table RAM at $0000 to $2000 of size $2000 (8kB)
logic [7:0] ppu_ram0q;
assign ppu_data = ppu_wr && ppu_addr[13] == 1'b0 ? ppu_ram0q : 8'bz;
ram8k ppu_ram0 (
	.aclr(~n_reset), .clock(clkPPU),
	.address(ppu_addr[12:0]), .data(ppu_data),
	.wren(~ppu_wr && ppu_addr[13] == 1'b0), .q(ppu_ram0q));

// PPU nametable RAM at $2000 to $3000 of size $1000 (4kB)
logic [7:0] ppu_ram1q;
assign ppu_data = ppu_wr && ppu_addr[13] == 1'b1 ? ppu_ram1q : 8'bz;
ram4k ppu_ram1 (
	.aclr(~n_reset), .clock(clkPPU),
	.address(ppu_addr[11:0]), .data(ppu_data),
	.wren(~ppu_wr && ppu_addr[13] == 1'b1), .q(ppu_ram1q));

// Mappers
mapper map0 (.*);

endmodule
