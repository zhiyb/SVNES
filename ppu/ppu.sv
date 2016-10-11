module ppu (
	sys_if sys,
	sysbus_if sysbus,
	input logic clkPPU,
	output logic nmi,
	// PPU bus interface
	output logic [13:0] ppu_addr,
	inout wire [7:0] ppu_data,
	output logic ppu_rd, ppu_we,
	// Rendering output
	output logic [9:0] out_x, out_y,
	output logic [23:0] out_rgb,
	output logic out_we
);

// Reset signal
logic reset;

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
logic nmi_en, ms, sp_size, bg_pt, sp_pt, vram_inc;
logic [1:0] nt_addr_set;
assign {nmi_en, ms, sp_size, bg_pt, sp_pt, vram_inc, nt_addr_set} = regs[0];

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

// PPU bus interface
logic [13:0] addr;
logic [7:0] data, data_out;
logic we, rd;

// CPU data access
assign data_out = data_reg;
assign we = wr_reg && addr_reg == 7;
assign rd = rd_reg && addr_reg == 7;

always_ff @(posedge sys.clk)
	reg_data_out <= data;

// Internal palette control RAM
logic pal_sel;
assign pal_sel = ppu_addr[13:8] == {6{1'b1}};
logic [4:0] pal_bus_addr, pal_addr;
assign pal_bus_addr = {ppu_addr[1:0] == 0 ? 1'b0 : ppu_addr[4], ppu_addr[3:0]};
logic [7:0] pal_bus_data, pal_data;
ramdual32 ram0 (.aclr(reset), .clock(clkPPU),
	.address_a(pal_bus_addr), .data_a(data_out), .q_a(pal_bus_data), .wren_a(we & pal_sel),
	.address_b(pal_addr), .data_b(8'h0), .q_b(pal_data), .wren_b(1'b0));

// Unified bus
assign ppu_addr = addr;
assign ppu_we = we & ~pal_sel;
assign ppu_data = ppu_we ? data_out : 8'hz;
assign data = pal_sel ? pal_bus_data : ppu_data;

// Renderer
parameter vblanking = 20, vpost = 1;
parameter vlines = 240 + vpost + vblanking + 1;
//ppu_renderer renderer0 (.n_reset(sys.n_reset), .req(rdr_req), .addr(rdr_addr), .*);

// Frame counters
logic skip;
logic [8:0] x, y;
always_ff @(posedge clkPPU, negedge sys.n_reset)
	if (~sys.n_reset)
		x <= 0;
	else if (skip && x == 339 && y == vlines - 1)
		x <= 0;
	else if (x == 340)
		x <= 0;
	else
		x <= x + 1;

always_ff @(posedge clkPPU, negedge sys.n_reset)
	if (~sys.n_reset)
		y <= 0;
	else if (skip && x == 339 && y == vlines - 1)
		y <= 0;
	else if (x == 340) begin
		if (y == vlines - 1)
			y <= 0;
		else
			y <= y + 1;
	end

always_ff @(posedge clkPPU, negedge sys.n_reset)
	if (~sys.n_reset)
		skip <= 1'b0;
	else if (x == 0 && y == 0)
		skip <= ~skip;

logic rendering;
assign rendering = (y < 240 || y >= vlines - 1) && bg_en && sp_en;

// v, t, x, w registers
logic [14:0] v, v_load, t;
logic [4:0] coarse_x, coarse_y;
logic [2:0] fine_x, fine_y;
logic [1:0] nt;
logic w;

always_ff @(posedge clkPPU)
	if (reset)
		t <= 15'h0;
	else if (wr_reg) begin
		case (addr_reg)
		0: t[11:10] <= data_reg[1:0];
		5: if (~w)
				t[4:0] <= data_reg[4:0];
			else
				{t[9:5], t[14:12]} <= data_reg;
		6: if (~w)
				t[14:8] <= {1'b0, data_reg[5:0]};
			else
				t[7:0] <= data_reg;
		endcase
	end

always_ff @(posedge clkPPU)
	if (reset)
		v <= 0;
	else if (wr_reg && addr_reg == 6 && w == 1)
		v <= {t[14:8], data_reg};
	else if ((wr_reg || rd_reg) && addr_reg == 7)
		v <= v_load;
	else if (rendering) begin
		if (x == 255)
			v <= v_load;
		else if (x == 256)
			{v[10], v[4:0]} <= {t[10], t[4:0]};
		else if (x[2:0] == 7 && (x[8:3] < 32 || x[8:3] >= 40))
			{v[10], v[4:0]} <= {v_load[10], v_load[4:0]};
		if (y >= vlines - 1)
			if (x >= 279 && x < 303)
				{v[14:11], v[9:8], v[7:5]} <= {t[14:11], t[9:8], t[7:5]};
	end

always_ff @(posedge clkPPU)
	if (reset)
		fine_x <= 0;
	else if (wr_reg && addr_reg == 5 && w == 0)
		fine_x <= data_reg[2:0];

always_ff @(posedge clkPPU)
	if (reset)
		w <= 1'b0;
	else if (rd_reg && addr_reg == 2)
		w <= 1'b0;
	else if (wr_reg && (addr_reg == 5 || addr_reg == 6))
		w <= ~w;

assign {fine_y, nt, coarse_y, coarse_x} = v;

// Scrolling calculation
logic [1:0] nt_next;
logic [4:0] coarse_x_next;
assign {nt_next[0], coarse_x_next} = {nt[0], coarse_x} + 1;
logic y_inc;
logic [2:0] fine_y_next;
logic [4:0] coarse_y_next;
assign {y_inc, fine_y_next} = fine_y + 1;
always_comb
begin
	nt_next[1] = nt[1];
	coarse_y_next = coarse_y;
	if (y_inc) begin
		if (coarse_y_next == 29) begin
			coarse_y_next = 0;
			nt_next[1] = ~nt[1];
		end else
			coarse_y_next = coarse_y + 1;
	end
end

logic [14:0] v_next;
assign v_next = {fine_y_next, nt_next, coarse_y_next, coarse_x_next};

assign v_load = rendering ? v_next : v + (vram_inc ? 32 : 1);

// Address calculation
logic [13:0] data_addr;
assign data_addr = v[13:0];
logic [13:0] nt_addr;
assign nt_addr = {2'h2, nt, coarse_y, coarse_x};
logic [13:0] at_addr;
assign at_addr = {2'h2, nt, 4'b1111, coarse_y[4:2], coarse_x[4:2]};
logic [13:0] pt_addr[2];

logic [1:0] addr_sel;
always_ff @(posedge clkPPU)
	addr_sel <= x[2:1];

always_comb
begin
	addr = data_addr;
	if (rendering) begin
		case (addr_sel)
		0: addr = nt_addr;
		1: addr = at_addr;
		2: addr = pt_addr[0];
		3: addr = pt_addr[1];
		endcase
	end
end

assign ppu_rd = (rendering && x != 0) || rd;

// Data registers
logic [1:0] at_bit;
logic [7:0] nt_data, pt_data[2];

always_ff @(posedge clkPPU)
	if (~x[0]) begin
		case (addr_sel)
		0: nt_data <= data;
		1: at_bit <= data[2 * {coarse_y[0], coarse_x[0]} +: 2];
		2: pt_data[0] <= data;
		3: pt_data[1] <= data;
		endcase
	end

assign pt_addr[0] = {1'b0, bg_pt, nt_data, 1'b0, fine_y};
assign pt_addr[1] = {1'b0, bg_pt, nt_data, 1'b1, fine_y};

// Shift registers
logic [7:0] shift_a[2], shift_b[2], shift_p[2], shift_p_bit[2];
always_ff @(posedge clkPPU)
	if (x[2:0] == 1) begin
		shift_b[0] <= pt_data[0];
		shift_b[1] <= pt_data[1];
		shift_p_bit[0] <= at_bit[0];
		shift_p_bit[1] <= at_bit[1];
	end else begin
		shift_b[0] <= {shift_b[0][6:0], data[0]};
		shift_b[1] <= {shift_b[1][6:0], data[0]};
	end

always_ff @(posedge clkPPU)
	if (x <= 337 && x > 1) begin
		shift_a[0] <= {shift_a[0][6:0], shift_b[0][7]};
		shift_a[1] <= {shift_a[1][6:0], shift_b[1][7]};
		shift_p[0] <= {shift_p[0][6:0], shift_p_bit[0]};
		shift_p[1] <= {shift_p[1][6:0], shift_p_bit[1]};
	end

// Pixel output
logic [1:0] pixel, palette;
assign pixel = {shift_a[1][fine_x], shift_a[0][fine_x]};
assign palette = {shift_p[1][fine_x], shift_p[0][fine_x]};
assign pal_addr = {1'b0, pixel == 2'b0 ? 2'b0 : palette, pixel};

assign out_x = x + 128, out_y = y + 128;
assign out_we = bg_en && sp_en &&  x < 256 && y < 240;
assign out_rgb = {pal_data[7:5], 5'b0, pal_data[4:2], 5'b0, pal_data[1:0], 6'b0};

// vblank flag
logic vblank;
always_ff @(posedge clkPPU)
	if (rd_reg && addr_reg == 2)
		vblank <= 1'b0;
	else if (x == 0) begin
		if (y == 240 + vpost)
			vblank <= 1'b1;
		else if (y == vlines - 1)
			vblank <= 1'b0;
	end

always_ff @(posedge sys.clk)
	vblank_cpu <= vblank;

// Reset signal
always_ff @(posedge clkPPU, negedge sys.n_reset)
	if (~sys.n_reset)
		reset <= 1'b1;
	else if (x == 0 && y == vlines - 1)
		reset <= 1'b0;

// TODO
assign sp_hit0 = 1'b0, sp_ovf = 1'b0;
assign reg_oam_data = 8'h0;
assign nmi = 1'b0;

endmodule
