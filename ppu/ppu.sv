module ppu (
	sys_if sys,
	sysbus_if sysbus,
	input logic clk_PPU,
	output logic nmi
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
		regs[sysbus.addr[2:0]] <=  sysbus.data;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		oam_dma <= 8'h0;
	else if (sysbus.addr == 16'h4014 && sysbus.we)
		oam_dma <= sysbus.data;

logic [7:0] reg_status, reg_oam_data, reg_data_out;
always_comb
begin
	sysbus.data = 8'bz;
	if (sel && ~sysbus.we)
		case (sysbus.addr[2:0])
		3'h2:	sysbus.data = reg_status;
		3'h4:	sysbus.data = reg_oam_data_out;
		3'h7:	sysbus.data = reg_data_out;
		endcase
end

// Separation of register fields

logic nmi_en, ms, sp_size, bg_addr, sp_addr, vram_inc;
logic [1:0] nt_addr;
assign {nmi_en, ms, sp_size, bg_addr, sp_addr, vram_inc, nt_addr} = regs[0];

logic [2:0] emph;
logic sp_en, bg_en, sp_left, bg_left, gray;
assign {emph, sp_en, bg_en, sp_left, bg_left, gray} = regs[1];

logic vb_started, sp_hit0, sp_ovf;
assign reg_status = {vb_started, sp_hit0, sp_ovf, 5'bx};

logic [7:0] oam_addr;
assign oam_addr = regs[3];

logic [7:0] oam_data;
assign oam_data = regs[4];

logic [7:0] reg_scroll;
assign reg_scroll = regs[5];

logic [7:0] reg_addr;
assign reg_addr = regs[6];

logic [7:0] reg_data;
assign reg_data = regs[7];

// TODO

assign vb_started = 1'b0, sp_hit0 = 1'b0, sp_ovf = 1'b0;
assign reg_oam_data_out = 8'h0;

endmodule
