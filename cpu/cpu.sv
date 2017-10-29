module cpu (
	input logic clk, dclk, n_reset,
	input logic nmi, irq, ready,
	output logic [15:0] addr,
	inout wire [7:0] data,
	output logic rw
);

logic [7:0] bus_db, bus_sb, bus_adh, bus_adl, int_addr;
logic [7:0] abh, abl, dl, dout, alu;
logic [7:0] y, x, sp, a, p, pch, pcl;
// Overflow, carry out, relative carry out, branch, IRQ pending
logic avr, acr, arc, br, irq_pending;

// Halting control
logic run, runc;
// Only halts at read cycles
assign run = ~rw | ready;
always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		runc <= 1'b0;
	else
		runc <= run;

// {{{ Microcode controller
typedef enum logic [2:0] {ALU_ADD = 3'h0, ALU_SUB = 3'h1, ALU_SL = 3'h2, ALU_SR = 3'h3, ALU_AND = 3'h4, ALU_OR = 3'h5, ALU_EOR = 3'h6, ALU_REL = 3'h7} ALUop_t;
typedef enum logic       {AI_0 = 1'h0, AI_SB = 1'h1} ALUAI_t;
typedef enum logic       {AI_HLD = 1'h1} ALUAI1_t;
typedef enum logic [1:0] {BI_DB = 2'h0, BI_nDB = 2'h1, BI_ADL = 2'h2, BI_HLD = 2'h3} ALUBI_t;
typedef enum logic [2:0] {DB_DL = 3'h0, DB_PCL = 3'h1, DB_PCH = 3'h2, DB_SB = 3'h3, DB_A = 3'h4, DB_P = 3'h5} DB_t;
typedef enum logic [2:0] {SB_ALU = 3'h0, SB_SP = 3'h1, SB_X = 3'h2, SB_Y = 3'h3, SB_A = 3'h4, SB_DB = 3'h5, SB_FUL = 3'h7} SB_t;
typedef enum logic [2:0] {AD_0A = 3'h0, AD_DA = 3'h1, AD_1S = 3'h2, AD_DS = 3'h3, AD_0D = 3'h4, AD_PC = 3'h6, AD_FI = 3'h7} AD_t;
typedef enum logic [2:0] {AD_HLD = 3'h0, AD_ADL = 3'h1, AD_ADH = 3'h2} AD1_t;
typedef enum logic       {PC_PC = 1'h0, PC_AD = 1'h1} PC_t;
typedef enum logic [1:0] {P_MASK = 2'h0, P_SP = 2'h1, P_CLR = 2'h2, P_SET = 2'h3} Pop_t;
typedef enum logic [1:0] {P_NONE = 2'h0, P_NZ = 2'h1, P_NZC = 2'h2, P_NVZC = 2'h3} P_t;
typedef enum logic [1:0] {P_PUSH = 2'h0, P_POP = 2'h1, P_BIT = 2'h2} Psp_t;
typedef enum logic [1:0] {P_C = 2'h0, P_D = 2'h1, P_I = 2'h2, P_V = 2'h3} Pf0_t;
typedef enum logic [1:0] {P_Z = 2'h1, P_N = 2'h2, P_B = 2'h3} Pf1_t;
typedef enum logic	 {READ = 1'h0, WRITE = 1'h1} WR_t;
typedef enum logic [1:0] {SEQ_0 = 2'h0, SEQ = 2'h1, SEQ_2 = 2'h2} SEQ_t;

struct packed {
	ALUop_t alu;	// 3
	logic alu_c;
	ALUAI_t ai;	// 1
	ALUBI_t bi;	// 2
	DB_t db;	// 3
	SB_t sb;	// 3
	logic sb_a, sb_x, sb_y, sb_sp;
	logic ad_sp;
	AD_t ad;	// 3
	PC_t pc;	// 1
	logic pc_inc;
	logic p_chk;
	Pop_t pop;	// 2
	P_t p;		// 2
	WR_t wr;	// 1
	logic seq_rom;
	SEQ_t seq;	// 2
} mop;

logic [7:0] mop_addr, mop_addrn;
logic [31:0] rom_mop;
rom_mop rom0 (~n_reset, mop_addr, clk, runc, rom_mop);
assign mop = rom_mop[31:0];

logic rom_rden;
assign rom_rden = mop.seq_rom && mop.seq == 0;
logic [7:0] rom_dl;
always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		rom_dl <= 0;
	else if (rom_rden)
		rom_dl <= data;

logic [9:0] rom_op;
logic [7:0] mop_jump;
rom_mop_dispatch rom1 (~n_reset, rom_op, dclk, mop.seq_rom, mop_jump);
assign rom_op[1:0] = mop.seq;
assign rom_op[9:2] = mop.seq == 0 ? (irq_pending ? 8'h00 : data) : rom_dl;

logic mop_rst;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		mop_rst <= 1'b0;
	else
		mop_rst <= rom_rden && mop_jump == 0;

logic irq_op;
assign irq_op = irq_pending & rom_rden;

always_comb
	if (mop.p_chk & br)
		mop_addr = mop_addrn + 1;
	else if (mop.seq_rom)
		mop_addr = mop_jump;
	else if (mop.seq == SEQ_0)
		mop_addr = 0;
	else
		mop_addr = mop_addrn + mop.seq;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		mop_addrn <= 0;
	else if (runc)
		mop_addrn <= mop_addr;
// }}}

// {{{ Buses
always_comb
	case (mop.sb)
	SB_ALU:	bus_sb = alu;
	SB_SP:	bus_sb = sp;
	SB_X:	bus_sb = x;
	SB_Y:	bus_sb = y;
	SB_A:	bus_sb = a;
	SB_DB:	bus_sb = bus_db;
	SB_FUL:	bus_sb = 8'hff;
	default: bus_sb = 'bx;
	endcase

always_comb
	case (mop.db)
	DB_DL:	bus_db = dl;
	DB_PCL:	bus_db = pcl;
	DB_PCH: bus_db = pch;
	DB_SB:	bus_db = bus_sb;
	DB_A:	bus_db = a;
	DB_P:	bus_db = p;
	default: bus_db = 'bx;
	endcase

always_comb
begin
	case (mop.ad)
	AD_0A:	{bus_adh, bus_adl} = {8'h0, alu};
	AD_0D:	{bus_adh, bus_adl} = {8'h0, dl};
	AD_1S:	{bus_adh, bus_adl} = {8'h1, sp};
	AD_DS:	{bus_adh, bus_adl} = {dl, sp};
	AD_DA:	{bus_adh, bus_adl} = {dl, alu};
	AD_PC:	{bus_adh, bus_adl} = {pch, pcl};
	AD_FI:	{bus_adh, bus_adl} = {8'hff, int_addr};
	default: {bus_adh, bus_adl} = 'bx;
	endcase
	if (~mop.ad_sp)
		{bus_adh, bus_adl} = {bus_sb, alu};
end

assign addr = {abh, abl};
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		{abh, abl} <= 0;
	else if (~mop.ad_sp) begin
		if (mop.ad[0])
			abl <= bus_adl;
		if (mop.ad[1])
			abh <= bus_adh;
	end else
		{abh, abl} <= {bus_adh, bus_adl};

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		dout <= 0;
	else
		dout <= bus_db;
assign rw = mop.wr == READ ? 1 : 0;
assign data = rw ? 8'bz : dout;
// }}}

// {{{ Status register
typedef enum {
	S_N = 7, S_V = 6, S_R = 5, S_B = 4, S_D = 3, S_I = 2, S_Z = 1, S_C = 0
} Pf_t;

logic [7:0] pn;
// FIXME: S_Z should be checking bus_db
assign pn = {bus_db[7], avr, 1'b1, p[S_B], p[S_D], p[S_I], bus_sb == 0, acr};

logic [7:0] pbr;
always_comb
begin
	pbr = p;
	if (~mop.pop[1]) begin
		pbr[S_C] = pn[S_C];
		pbr[S_V] = arc;
	end
	br = 1'b0;
	case (mop.p)
	P_N:	br = pbr[S_N];
	P_V:	br = pbr[S_V];
	P_C:	br = pbr[S_C];
	P_Z:	br = pbr[S_Z];
	endcase
	br = br ^ mop.pop[0];
end

logic pbit;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		pbit <= 1'b0;
	else
		pbit <= bus_db[6];

logic [7:0] pspn;
always_comb
begin
	pspn = bus_db;
	case (mop.p)
	P_BIT:	{pspn[S_V], pspn[S_Z]} = {pbit, pn[S_Z]};
	endcase
end

logic [7:0] pmask;
always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		pmask <= 0;
	else begin
		pmask <= 0;
		case (mop.pop)
		P_MASK:	case (mop.p)
			P_NZ:	{pmask[S_N], pmask[S_Z]} <= 2'b11;
			P_NZC:	{pmask[S_N], pmask[S_Z:S_C]} <= 3'b111;
			P_NVZC:	{pmask[S_N:S_V], pmask[S_Z:S_C]} <= 4'b1111;
			endcase
		P_SP:	case (mop.p)
			P_PUSH:	{pmask[S_N:S_V], pmask[S_D:S_C]} <= 6'b111111;
			P_POP:	{pmask[S_N:S_V], pmask[S_D:S_C]} <= 6'b111111;
			P_BIT:	{pmask[S_V], pmask[S_Z]} <= 2'b11;
			endcase
		P_CLR:	case (mop.p)
			P_C:	pmask[S_C] <= 1'b1;
			P_D:	pmask[S_D] <= 1'b1;
			P_I:	pmask[S_I] <= 1'b1;
			P_V:	pmask[S_V] <= 1'b1;
			endcase
		P_SET:	case (mop.p)
			P_C:	pmask[S_C] <= 1'b1;
			P_D:	pmask[S_D] <= 1'b1;
			P_I:	pmask[S_I] <= 1'b1;
			P_B:	pmask[S_B] <= ~irq_pending;
			endcase
		endcase
	end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		p <= 0;
		p[S_R] <= 1'b1;
	end else if (!mop.p_chk) begin
		case (mop.pop)
		P_MASK:	p <= (p & ~pmask) | (pn & pmask);
		P_SP:	p <= (p & ~pmask) | (pspn & pmask);
		P_SET:	p <= p | pmask;
		P_CLR:	p <= p & ~pmask;
		endcase
		p[S_R] <= 1'b1;
	end
// }}}

// {{{ Interrupts
logic [1:0] nmi_latch;
logic irq_latch;
always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset) begin
		nmi_latch <= 2'b0;
		irq_latch <= 1'b0;
	end else begin
		nmi_latch <= {nmi_latch[0], nmi};
		irq_latch <= irq;
	end

logic rst_act, nmi_act, irq_act, irq_jump;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		rst_act <= 1'b1;
		nmi_act <= 1'b0;
		irq_act <= 1'b0;
		irq_pending <= 1'b1;
		irq_jump <= 1'b0;
	end else begin
		if (mop_rst)
			rst_act <= 1'b1;
		else if (irq_jump)
			rst_act <= 1'b0;
		if (nmi_latch[1] & ~nmi_latch[0])
			nmi_act <= 1'b1;
		else if (irq_jump & ~rst_act)
			nmi_act <= 1'b0;
		irq_act <= ~irq_latch;
		irq_pending <= rst_act | nmi_act | (irq_act & ~p[S_I]);
		irq_jump <= irq_pending && mop.ad_sp && mop.ad == AD_FI;
	end

always_comb
begin
	int_addr = 8'hfe;
	if (rst_act)
		int_addr = 8'hfc;
	else if (nmi_act)
		int_addr = 8'hfa;
end
// }}}

// {{{ Program counter & registers
logic load_pc;
always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		load_pc <= 1'b0;
	else if (run)
		load_pc <= mop.pc == PC_AD;

always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		{pch, pcl} <= 0;
	else if (~run)
		;
	else if (load_pc)
		{pch, pcl} <= addr + (~irq_op ? 1 : 0);
	else
		{pch, pcl} <= {pch, pcl} + ((mop.pc_inc & ~irq_op) ? 1 : 0);

always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		dl <= 0;
	else if (run)
		dl <= data;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		y <= 0;
		x <= 0;
		sp <= 0;
		a <= 0;
	end else if (runc) begin
		if (mop.sb_y)
			y <= bus_sb;
		if (mop.sb_x)
			x <= bus_sb;
		if (mop.sb_a)
			a <= bus_sb;
		if (mop.sb_sp)
			sp <= bus_sb;
	end
// }}}

// {{{ ALU
logic ac;
assign ac = mop.alu[0] ^ (mop.alu_c & p[S_C]);

logic [7:0] ai, bi;
logic [8:0] alu_sum, alu_sr, alu_sl;
logic [7:0] alu_and, alu_or, alu_eor, alu_rel;
assign alu_sum = ai + bi + (ac ? 1 : 0);
assign alu_and = ai & bi;
assign alu_or = ai | bi;
assign alu_eor = ai ^ bi;
assign alu_sr = {mop.alu_c & p[S_C], ai[7:0]};
assign alu_sl = {ai[7:0], mop.alu_c & p[S_C]};

always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		{avr, acr, alu} <= 0;
	else if (run) begin
		{acr, alu} <= alu_sum;
		arc <= ai[7] ^ alu_sum[8];
		avr <= ~(ai[7] ^ bi[7]) & (ai[7] ^ alu_sum[7]);
		case (mop.alu)
		ALU_SL:		{acr, alu} <= alu_sl;
		ALU_SR:		{alu, acr} <= alu_sr;
		ALU_AND:	alu <= alu_and;
		ALU_OR:		alu <= alu_or;
		ALU_EOR:	alu <= alu_eor;
		ALU_REL:	alu <= alu_rel;
		endcase
	end

logic [7:0] ai_reg, bi_reg;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		ai_reg <= 0;
		bi_reg <= 0;
	end else if (runc) begin
		ai_reg <= ai;
		bi_reg <= bi;
	end

assign alu_rel = {8{ai_reg[7]}} + (acr ? 1 : 0) + bi;

always_comb
begin
	case (mop.ai)
	AI_0:	ai = 0;
	AI_SB:	ai = bus_sb;
	default: ai = 'bx;
	endcase
	case (mop.bi)
	BI_DB:	bi = bus_db;
	BI_nDB:	bi = ~bus_db;
	BI_ADL:	bi = bus_adl;
	// TODO: Check if STA (d, x) breaks
	BI_HLD:	bi = bi_reg;
	default: bi = 'bx;
	endcase
	if (mop.bi == BI_HLD && mop.ai == AI_HLD)
		ai = ai_reg;
end
// }}}

endmodule
