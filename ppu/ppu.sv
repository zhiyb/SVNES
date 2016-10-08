module ppu (
	sys_if sys,
	sysbus_if sysbus,
	input logic clkPPU,
	output logic nmi,
	// PPU bus interface
	output logic [13:0] ppu_addr,
	inout wire [7:0] ppu_data,
	output logic ppu_we,
	// Rendering output
	output logic [8:0] out_x, out_y,
	output logic [23:0] out_rgb,
	output logic out_we
);

// Registers
logic [7:0] regs[8], oam_dma;

logic sel;
assign sel = sysbus.addr[15:13] == 3'h1;
assign sysbus.rdy = sel ? 1'b1 : 1'bz;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		for (int i = 0; i != 8; i++)
			regs[i] <= 8'h0;
	else if (sel & sysbus.we)
		regs[sysbus.addr[2:0]] <= sysbus.data;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		oam_dma <= 8'h0;
	else if (sysbus.addr == 16'h4014 && sysbus.we)
		oam_dma <= sysbus.data;

// Register reading
logic [7:0] bus_out, reg_status, reg_oam_data, reg_data_out;
assign sysbus.data = sel && ~sysbus.we ? bus_out : 8'bz;
always_comb
begin
	bus_out = 8'h0;
	if (sel && ~sysbus.we)
		case (sysbus.addr[2:0])
		3'd2:	bus_out = reg_status;
		3'd4:	bus_out = reg_oam_data;
		3'd7:	bus_out = reg_data_out;
		endcase
end

// Separation of register fields
logic nmi_en, ms, sp_size, bg_addr, sp_addr, vram_inc;
logic [1:0] nt_addr;
assign {nmi_en, ms, sp_size, bg_addr, sp_addr, vram_inc, nt_addr} = regs[0];

logic [2:0] emph;
logic sp_en, bg_en, sp_left, bg_left, gray;
assign {emph, sp_en, bg_en, sp_left, bg_left, gray} = regs[1];

logic vblank_cpu, sp_hit0, sp_ovf;
assign reg_status = {vblank_cpu, sp_hit0, sp_ovf, 5'bx};

logic [7:0] oam_addr;
assign oam_addr = regs[3];

logic [7:0] oam_data;
assign oam_data = regs[4];

// Inter-clock-domain synchronisation
logic clkCPU[2];
always_ff @(posedge clkPPU)
begin
	clkCPU[0] <= sys.clk;
	clkCPU[1] <= ~clkCPU[0];
end

logic update;
assign update = clkCPU[0] & clkCPU[1];

logic rd_reg, wr_reg;
logic [2:0] addr_reg;
logic [7:0] data_reg;
always_ff @(posedge clkPPU)
	if (update) begin
		rd_reg <= sel & ~sysbus.we;
		wr_reg <= sel & sysbus.we;
		addr_reg <= sysbus.addr;
		data_reg <= sysbus.data;
	end else begin
		rd_reg <= 1'b0;
		wr_reg <= 1'b0;
	end

// Register access signals
logic read_status, read_data;
logic write_scroll, write_addr, write_data;
always_comb
begin
	read_status = 1'b0;
	write_scroll = 1'b0;
	write_addr = 1'b0;
	read_data = 1'b0;
	write_data = 1'b0;
	case (addr_reg)
	3'd2:	read_status = rd_reg;
	3'd5: write_scroll = wr_reg;
	3'd6: write_addr = wr_reg;
	3'd7:	begin
		read_data = rd_reg;
		write_data = wr_reg;
	end
	endcase
end

// PPU bus interface
logic [13:0] addr;
logic [7:0] data, data_out;
logic we;

// CPU data access
assign data_out = data_reg;
assign we = write_data;

always_ff @(posedge sys.clk)
	reg_data_out <= data;

// 16bit latch
logic write_toggle;
always_ff @(posedge clkPPU)
	if (read_status)
		write_toggle <= 1'b0;
	else if (write_addr || write_scroll)
		write_toggle <= ~write_toggle;

logic [15:0] data_latch;
always_ff @(posedge clkPPU)
	if (write_addr || write_scroll) begin
		if (~write_toggle)
			data_latch[15:8] <= data_reg;
		else
			data_latch[7:0] <= data_reg;
	end

// Address calculation
always_ff @(posedge clkPPU)
	if (write_addr && write_toggle)
		addr <= {data_latch[15:8], data_reg};
	else if (read_data || write_data)
		addr <= addr + (vram_inc ? 32 : 1);

// Internal palette control RAM
logic pal_sel;
assign pal_sel = ppu_addr[13:5] == {9{1'b1}};
logic [7:0] pal_data;
ram32 ram0 (.aclr(~sys.n_reset), .clock(clkPPU),
	.address(ppu_addr[4:0]), .data(data_out), .q(pal_data),
	.wren(we & pal_sel));

// Unified bus
assign ppu_addr = addr;
assign ppu_we = we & ~pal_sel;
assign ppu_data = ppu_we ? data_out : 8'hz;
assign data = pal_sel ? pal_data : ppu_data;

// Renderer
parameter vblanking = 20, vpost = 1;
parameter vlines = 240 + vpost + vblanking + 1;
//ppu_renderer renderer0 (.n_reset(sys.n_reset), .req(rdr_req), .addr(rdr_addr), .*);

// Frame counters
always_ff @(posedge clkPPU, negedge sys.n_reset)
	if (~sys.n_reset)
		out_x <= 0;
	else if (out_x == 340)
		out_x <= 0;
	else
		out_x <= out_x + 1;

always_ff @(posedge clkPPU, negedge sys.n_reset)
	if (~sys.n_reset)
		out_y <= vlines - 1;
	else if (out_x == 340) begin
		if (out_y == vlines - 1)
			out_y <= 0;
		else
			out_y <= out_y + 1;
	end

// vblank flag
logic vblank;
always_ff @(posedge clkPPU)
	if (out_x == 0) begin
		if (out_y == 240 + vpost)
			vblank <= 1'b1;
		else if (read_status)
			vblank <= 1'b0;
		else if (out_y == vlines - 1)
			vblank <= 1'b0;
	end

always_ff @(posedge sys.clk)
	vblank_cpu <= vblank;

// TODO
assign sp_hit0 = 1'b0, sp_ovf = 1'b0;
assign reg_oam_data = 8'h0;
assign nmi = 1'b0;

endmodule
