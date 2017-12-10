module system (
	input logic clkCPU2, clkPPU, n_reset,
	// External interface
	output logic clkCPU, clkCPUn, clkRAM,
	input logic sys_reset,
	input wire sys_irq,
	// CPU bus
	output logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	output logic sys_rw,
	output wire sys_rdy,
	// PPU bus
	output logic [13:0] ppu_addr,
	inout wire [7:0] ppu_data,
	output logic ppu_rd, ppu_wr,
	// Audio
	output logic [7:0] audio,
	// Video
	output logic [23:0] video_rgb,
	output logic video_vblank, video_hblank
);

// Clock generation
logic clk, dclk;
assign clkCPU = clk;
assign clkCPUn = dclk;
always_ff @(posedge clkCPU2, negedge n_reset)
	if (~n_reset) begin
		clk <= 1'b1;
		dclk <= 1'b1;
	end else begin
		clk <= ~clk;
		dclk <= clk;
	end

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
logic nmi, irq;
cpu cpu0 (clk, dclk, n_reset, sys_reset, nmi, irq,
	sys_rdy, sys_addr, sys_data, sys_rw);
assign arb_req[1] = 1'b1;

// APU
logic [15:0] apu_addr;
logic apu_rdy, apu_req, apu_irq;
logic [7:0] apu_out;
apu apu0 (clk, dclk, n_reset, sys_addr, sys_data, sys_rdy, ~sys_rw,
	apu_addr, apu_rdy, apu_req, apu_irq, apu_out);
assign apu_rdy = 1'b0;
assign irq = apu_irq & sys_irq;
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
ppu ppu0 (clk, dclk, clkPPU, n_reset, sys_reset, ppu_nmi,
	sys_addr, sys_data, sys_rdy, sys_rw,
	ppu_addr, ppu_data, ppu_rd, ppu_wr,
	video_rgb, video_vblank, video_hblank);
assign nmi = ppu_nmi;

// PPU nametable RAM at $2000 to $3000 of size $1000 (4kB)
logic [7:0] ppu_ram1q;
assign ppu_data = ppu_wr && ppu_addr[13] == 1'b1 ? ppu_ram1q : 8'bz;
ram4k ppu_ram1 (
	.aclr(~n_reset), .clock(clkPPU),
	.address(ppu_addr[11:0]), .data(ppu_data),
	.wren(~ppu_wr && ppu_addr[13] == 1'b1), .q(ppu_ram1q));

endmodule
