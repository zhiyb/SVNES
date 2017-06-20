module cpu (
	input logic clk, dclk, n_reset,
	output logic [15:0] addr,
	inout wire [7:0] data,
	output logic rw
);

logic [7:0] bus_db, bus_sb, bus_adh, bus_adl;
logic [7:0] abh, abl, alu;
logic [7:0] y, x, sp, a, p, pch, pcl, dl;

typedef enum logic [2:0] {ALU_ADD = 3'h0} ALUop_t;
typedef enum logic       {AI_0 = 1'h0, AI_SB = 1'h1} ALUAI_t;
typedef enum logic [1:0] {BI_DB = 2'h0, BI_nDB = 2'h1, BI_ADL = 2'h2} ALUBI_t;
typedef enum logic [2:0] {DB_DL = 3'h0, DB_PCL = 3'h1, DB_PCH = 3'h2, DB_SB = 3'h3, DB_A = 3'h4, DB_P = 3'h5} DB_t;
typedef enum logic [2:0] {SB_ALU = 3'h0, SB_SP = 3'h1, SB_X = 3'h2, SB_Y = 3'h3, SB_A = 3'h4} SB_t;
typedef enum logic [2:0] {AD_PC = 3'h0, AD_ZP = 3'h1, AD_SP = 3'h2, AD_ABS = 3'h3} AD_t;
typedef enum logic       {PC_PC = 1'h0, PC_AD = 1'h1} PC_t;
typedef enum logic [1:0] {P_MASK = 2'h0, P_SP = 2'h1, P_CLR = 2'h2, P_SET = 2'h3} Pop_t;
typedef enum logic [1:0] {P_NONE = 2'h0, P_NZ = 2'h1, P_NZC = 2'h2, P_NVZC = 2'h3} P_t;
typedef enum logic [1:0] {P_POP = 2'h0, P_BIT = 2'h1, P_BRK = 2'h2} Psp_t;
typedef enum logic [1:0] {P_C = 2'h0, P_D = 2'h1, P_I = 2'h2, P_V = 2'h3} Pf0_t;
typedef enum logic [1:0] {P_Z = 2'h1, P_N = 2'h2} Pf1_t;
typedef enum logic	 {READ = 1'h0, WRITE = 1'h1} WR_t;
typedef enum logic [1:0] {SEQ_0 = 2'h0, SEQ = 2'h1} SEQ_t;

struct packed {
	ALUop_t alu;	// 3
	ALUAI_t ai;	// 1
	ALUBI_t bi;	// 2
	DB_t db;	// 3
	logic db_p;
	SB_t sb;	// 3
	logic sb_a, sb_x, sb_y, sb_sp;
	AD_t ad;	// 3
	logic ad_ab;
	PC_t pc;	// 1
	logic pc_inc;
	logic p_chk;
	Pop_t pop;	// 2
	P_t p;		// 2
	WR_t wr;
	logic seq_rom;
	SEQ_t seq;	// 2
} mop;

logic [9:0] mop_addr, mop_addrn;
logic [31:0] rom_mop;
rom_mop rom0 (~n_reset, mop_addr, clk, rom_mop);
assign mop = rom_mop[31:0];

logic rom_rden;
logic [31:0] rom_dispatch;
rom_mop_dispatch rom1 (~n_reset, data, dclk, rom_rden, rom_dispatch);
logic [9:0] rom_addr[3];
assign {rom_addr[2], rom_addr[1], rom_addr[0]} = rom_dispatch;

always_comb
	if (mop.seq_rom)
		mop_addr = rom_addr[mop.seq];
	else if (mop.seq == SEQ)
		mop_addr = mop_addrn;
	else
		mop_addr = 0;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		rom_rden <= 1'b0;
		mop_addrn <= 0;
	end else begin
		rom_rden <= mop_addr == 0;
		mop_addrn <= mop_addr + 1;
	end

always_comb
begin
	case (mop.sb)
	SB_ALU:	bus_sb = alu;
	SB_SP:	bus_sb = sp;
	SB_X:	bus_sb = x;
	SB_Y:	bus_sb = y;
	SB_A:	bus_sb = a;
	default: bus_sb = 'bx;
	endcase
	case (mop.db)
	DB_DL:	bus_db = dl;
	DB_PCL:	bus_db = pcl;
	DB_PCH: bus_db = pch;
	DB_SB:	bus_db = bus_sb;
	DB_A:	bus_db = a;
	DB_P:	bus_db = p;
	default: bus_db = 'bx;
	endcase
	case (mop.ad)
	AD_PC:	{bus_adh, bus_adl} = {pch, pcl};
	AD_ZP:	{bus_adh, bus_adl} = {8'h0, alu};
	AD_SP:	{bus_adh, bus_adl} = {8'h1, sp};
	AD_ABS:	{bus_adh, bus_adl} = {bus_sb, dl};
	default: {bus_adh, bus_adl} = 'bx;
	endcase
end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		{abh, abl} <= 0;
	else if (mop.ad_ab)
		{abh, abl} <= {bus_adh, bus_adl};
assign addr = {abh, abl};
assign rw = mop.wr == READ ? 1 : 0;

logic [7:0] ai, bi;
always_comb
	case (mop.alu)
	ALU_ADD:	alu <= ai + bi;
	default:	alu <= 'bx;
	endcase

always_comb
begin
	case (mop.ai)
	AI_0:	ai = 0;
	AI_SB:	ai = bus_sb;
	default: ai = 'bx;
	endcase
	case (mop.sb)
	BI_DB:	bi = bus_db;
	BI_nDB:	bi = ~bus_db;
	BI_ADL:	bi = bus_adl;
	default: bi = 'bx;
	endcase
end

typedef enum {
	S_N = 7, S_V = 6, S_R = 5, S_B = 4, S_D = 3, S_I = 2, S_Z = 1, S_C = 0
} Pf_t;

logic [7:0] pn;
assign pn = {bus_db[7], 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, bus_db == 0, 1'b0};

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
		endcase
	end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		p <= 0;
		p[S_R] <= 1'b1;
	end else begin
		case (mop.pop)
		P_MASK:	p <= pmask & pn;
		endcase
		p[5] <= 1'b1;
	end

always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		{pch, pcl} <= 0;
	else if (mop.pc == PC_AD)
		{pch, pcl} <= {bus_adh, bus_adl} + (mop.pc_inc ? 1 : 0);
	else
		{pch, pcl} <= {pch, pcl} + (mop.pc_inc ? 1 : 0);

always_ff @(posedge dclk, negedge n_reset)
	if (~n_reset)
		dl <= 0;
	else
		dl <= data;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		y <= 0;
		x <= 0;
		sp <= 0;
		a <= 0;
	end else begin
		if (mop.sb_y)
			y <= bus_sb;
		if (mop.sb_x)
			x <= bus_sb;
		if (mop.sb_sp)
			sp <= bus_sb;
		if (mop.sb_a)
			a <= bus_sb;
	end

endmodule
