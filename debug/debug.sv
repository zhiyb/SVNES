module debug (
	input logic clkDebug, n_reset,
	// Processor requests
	output logic [19:0] addr,
	output logic [15:0] data,
	output logic req,
	// Debug info scan chain
	output logic dbg_load, dbg_shift,
	input logic dbg_din,
	output logic dbg_dout
);

// Clock generation
logic clk, dclk;
always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset) begin
		clk <= 1'b1;
		dclk <= 1'b1;
	end else begin
		clk <= ~clk;
		dclk <= clk;
	end

logic clkRAM;
always_ff @(negedge clkDebug, negedge n_reset)
	if (~n_reset)
		clkRAM <= 1'b1;
	else
		clkRAM <= clk;

// Processor
logic nmi, irq;
logic sys_reset;
logic sys_rdy;
logic [15:0] sys_addr;
wire [7:0] sys_data;
logic sys_rw;
cpu cpu0 (clk, dclk, n_reset, sys_reset, nmi, irq,
	sys_rdy, sys_addr, sys_data, sys_rw,
	1'b0, , 1'b0, 1'b0, 1'b0, 1'b0, );

assign sys_reset = 1'b0;
assign nmi = 1'b1;
assign irq = 1'b1;
assign sys_rdy = 1'b1;

// RAM at $0000 to $2000 of size $0800 (2kB)
logic ram0sel;
assign ram0sel = (sys_addr & ~16'h1fff) == 16'h0000;
logic [7:0] ram0q;
ram2k ram0 (.clock(clkRAM), .aclr(~n_reset),
	.address(sys_addr[10:0]), .data(sys_data),
	.wren(ram0sel & ~sys_rw), .q(ram0q));
assign sys_data = (ram0sel & sys_rw) ? ram0q : 8'bz;

// ROM at $8000 to $10000 of size $1000 (4kB)
logic rom0sel;
assign rom0sel = (sys_addr & ~16'h7fff) == 16'h8000;
logic [7:0] rom0q;
debug_rom rom0 (.clock(clkRAM), .address(sys_addr[11:0]), .q(rom0q));
assign sys_data = (rom0sel & sys_rw) ? rom0q : 8'bz;

// Special functions at $6000 to $7000
logic sp_sel;
assign sp_sel = (sys_addr & ~16'h0fff) == 16'h6000;
logic [19:0] fb_addr, fb_addrn, fb_addrp;
logic [15:0] fb_data;
always_ff @(posedge clkRAM)
	fb_addrn <= fb_addr + 1;
// Registers: addr[3], RESERVED, data[2], debug_ctrl, debug_data
logic [7:0] regs[8];
logic [7:0] dbg;
assign fb_addr = {regs[2][3:0], regs[1], regs[0]};
assign fb_data = {regs[5], regs[4]};
assign sys_data = (sp_sel & sys_rw) ? regs[sys_addr[2:0]] : 8'bz;
always_ff @(posedge clkRAM)
	if (sp_sel & ~sys_rw) begin
		regs[sys_addr[2:0]] <= sys_data;
		if (sys_addr[2:0] == 3'h4)
			{regs[2][3:0], regs[1], regs[0]} <= fb_addrn;
	end else begin
		regs[6] <= {dbg_shift, 7'h0};
		regs[7] <= dbg;
	end

// clkDebug synchronisation for frame buffer requests
logic fb_req;
assign fb_req = sp_sel & ~sys_rw && sys_addr[2:0] == 3'h4;
always_ff @(posedge clkRAM)
	fb_addrp <= fb_addr;
always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset) begin
		addr <= 0;
		data <= 0;
		req <= 1'b0;
	end else begin
		addr <= fb_addrp;
		data <= fb_data;
		if (req)
			req <= 1'b0;
		else if (fb_req)
			req <= 1'b1;
	end

// Debug info scan chain control
logic dbg_ctrl, dbg_data;
assign dbg_ctrl = sp_sel && sys_addr[2:0] == 3'h6;
assign dbg_data = sp_sel && sys_addr[2:0] == 3'h7;

logic dbg_ctrl_w, dbg_data_w;
always_ff @(posedge clkRAM)
begin
	dbg_ctrl_w <= dbg_ctrl & ~sys_rw;
	dbg_data_w <= dbg_data & ~sys_rw;
end

always_ff @(posedge clkDebug)
	dbg_load <= regs[6][6];

logic dbg_shift_start;
always_ff @(posedge clkDebug)
	dbg_shift_start <= dbg_data_w;

logic [2:0] dbg_cnt;
always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset)
		dbg_cnt <= 0;
	else if (dbg_cnt != 0)
		dbg_cnt <= dbg_cnt - 1;
	else if (dbg_shift_start)
		dbg_cnt <= 7;

always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset)
		dbg_shift <= 1'b0;
	else if (dbg_shift_start)
		dbg_shift <= 1'b1;
	else
		dbg_shift <= dbg_cnt != 0;

logic [7:0] dbg_sr;
assign dbg_dout = dbg_sr[7];
always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset)
		dbg_sr <= 0;
	else if (dbg_shift)
		dbg_sr <= {dbg_sr[6:0], dbg_din};
	else if (dbg_shift_start)
		dbg_sr <= dbg;

always_ff @(posedge clkDebug)
	if (dbg_data_w)
		dbg <= regs[7];
	else
		dbg <= dbg_sr;

endmodule
