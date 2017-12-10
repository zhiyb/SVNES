module mapper (
	input logic clkPPU, clkRAM, n_reset,
	// CPU bus
	input logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	input logic sys_rw,
	inout wire sys_rdy,
	// PPU bus
	input logic [13:0] ppu_addr,
	inout wire [7:0] ppu_data,
	input logic ppu_rd, ppu_wr,
	// System control
	output logic sys_reset,
	output wire sys_irq
);

// {{{ Common elements at CPU bus

// SRAM at $6000 to $8000 of size $2000 (8kB)
wire map_ram0_enable;
logic ram0sel;
assign ram0sel = map_ram0_enable && (sys_addr & ~16'h1fff) == 16'h6000;
assign sys_rdy = ram0sel ? 1'b1 : 1'bz;
logic [7:0] ram0q;
ram8k ram0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[12:0]), .data(sys_data),
	.wren(ram0sel & ~sys_rw), .q(ram0q));
assign sys_data = ram0sel & sys_rw ? ram0q : 8'bz;

// }}}

// {{{ Common elements at PPU bus

// PPU pattern table RAM at $0000 to $2000 of size $2000 (8kB)
wire map_ppu_ram0_enable;
logic ppu_ram0sel;
assign ppu_ram0sel = map_ppu_ram0_enable && ppu_addr[13] == 1'b0;
logic [7:0] ppu_ram0q;
ram8k ppu_ram0 (
	.aclr(~n_reset), .clock(clkPPU),
	.address(ppu_addr[12:0]), .data(ppu_data),
	.wren(ppu_ram0sel && ~ppu_wr), .q(ppu_ram0q));
assign ppu_data = ppu_ram0sel & ~ppu_rd ? ppu_ram0q : 8'bz;

// }}}

// Mapper control
logic [7:0] map_id;

// Mappers
mapper_boot map_boot (.enable(map_id == 8'd0), .*);

endmodule
