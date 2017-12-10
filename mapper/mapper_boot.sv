// Bootloader mapper
module mapper_boot (
	input logic clkRAM, n_reset,
	// CPU bus
	input logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	input logic sys_rw,
	inout wire sys_rdy,
	// System control
	output logic reset,
	// Common mapper elements
	output wire map_ram0_enable,
	// Mapper control
	output logic [7:0] map_id,
	input logic enable
);

logic en;
always_ff @(posedge clkRAM)
	en <= enable;

wire [7:0] data;
assign sys_data = en ? data : 8'bz;

// Common elements
assign map_ram0_enable = en ? 1'b1 : 1'bz;

// Startup ROM at $8000 to $10000 of size $8000 (32kB)
logic rom0sel;
assign rom0sel = en && (sys_addr & ~16'h7fff) == 16'h8000;
assign sys_rdy = rom0sel ? 1'b1 : 1'bz;
logic [7:0] rom0q;
rom4k rom0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[11:0]), .q(rom0q));
assign data = (rom0sel & sys_rw) ? rom0q : 8'bz;

// Control interface at $5000 to $6000
logic ctrl_sel;
assign ctrl_sel = en && (sys_addr & ~16'h0fff) == 16'h5000;
assign sys_rdy = ctrl_sel ? 1'b1 : 1'bz;
logic [11:0] ctrl_addr;
assign ctrl_addr = sys_addr[11:0];

// Mapper control interface at $000 to $100
logic map_sel;
assign map_sel = ctrl_sel && (ctrl_addr & ~12'h0ff) == 12'h000;
logic [7:0] map_addr;
assign map_addr = ctrl_addr[7:0];

// Mapper ID at $00
assign data = map_sel && map_addr == 8'h00 ? map_id : 8'bz;
always_ff @(posedge clkRAM, negedge n_reset)
	if (~n_reset) begin
		map_id <= 0;
		reset <= 1'b0;
	end else if (map_sel && map_addr == 8'h00) begin
		map_id <= sys_data;
		reset <= 1'b1;
	end else begin
		reset <= 1'b0;
	end

endmodule
