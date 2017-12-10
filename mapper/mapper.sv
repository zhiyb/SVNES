module mapper (
	input logic clkRAM, n_reset,
	input logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	input logic sys_rw,
	inout wire sys_rdy,
	output logic reset
);

// {{{ Common elements

// SRAM at $6000 to $8000 of size $2000 (8kB)
wire map_ram0_enable;
assign ram0sel = map_ram0_enable && (sys_addr & ~16'h1fff) == 16'h6000;
assign sys_rdy = ram0sel ? 1'b1 : 1'bz;
logic [7:0] ram0q;
ram8k ram0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[12:0]), .data(sys_data),
	.wren(ram0sel & ~sys_rw), .q(ram0q));
assign sys_data = (ram0sel & sys_rw) ? ram0q : 8'bz;

// }}}

// Mapper control
logic [7:0] map_id;

// Mappers
mapper_boot map_boot (.enable(map_id == 8'd0), .*);

endmodule
