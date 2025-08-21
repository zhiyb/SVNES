module C6502 (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        CLK_ENABLE_IN,

    // Interrupts
    input  logic        INT_RESET_IN,
    input  logic        INT_NMI_IN,
    input  logic        INT_IRQ_IN,

    // External bus
    output logic [15:0] ADDR_OUT,
    output logic        READ_ENABLE_OUT,
    input  logic [7:0]  READ_DATA_IN,
    output logic        WRITE_ENABLE_OUT,
    output logic [7:0]  WRITE_DATA_OUT
);

// CPU buses
typedef enum {
    SRC_00,
    SRC_01,
    SRC_FA,
    SRC_FB,
    SRC_FC,
    SRC_FD,
    SRC_FE,
    SRC_FF,
    SRC_ACC,
    SRC_ALU,
    SRC_ADD,
    SRC_X,
    SRC_Y,
    SRC_S,
    SRC_P,
    SRC_DB,
    SRC_SB,
    SRC_ADL,
    SRC_ADH,
    SRC_ABL,
    SRC_ABH,
    SRC_PCL,
    SRC_PCH,
    SRC_EXT
} src_t;

typedef logic [15:0] u16_t;
typedef logic [7:0]  u8_t;

u8_t adh, adl;

// Registers
u16_t pc;
u8_t a, x, y, p, s;
u8_t alu, add;

// External bus
typedef enum {
    EXT_PC,
    EXT_AD,
    EXT_S,
    EXT_IMM_FA,
    EXT_IMM_FB,
    EXT_IMM_FC,
    EXT_IMM_FD,
    EXT_IMM_FE,
    EXT_IMM_FF
} ext_bus_t;
ext_bus_t ext_bus;

typedef enum {
    EXT_DB_ALU,
    EXT_DB_PCH,
    EXT_DB_PCL,
    EXT_DB_P
} ext_db_t;
ext_db_t ext_db;

logic ext_access;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        ext_access <= 0;
    else
        ext_access <= CLK_ENABLE_IN;

logic ext_read, ext_write;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        ADDR_OUT         <= 0;
        READ_ENABLE_OUT  <= 0;
        WRITE_ENABLE_OUT <= 0;
        WRITE_DATA_OUT   <= 0;
    end else if (ext_access) begin

        if (ext_bus == EXT_PC)
            ADDR_OUT <= pc;
        else if (ext_bus == EXT_AD)
            ADDR_OUT <= {adh, adl};
        else if (ext_bus == EXT_S)
            ADDR_OUT <= {8'h01, s};
        else if (ext_bus == EXT_IMM_FA)
            ADDR_OUT <= 16'hfffa;
        else if (ext_bus == EXT_IMM_FB)
            ADDR_OUT <= 16'hfffb;
        else if (ext_bus == EXT_IMM_FC)
            ADDR_OUT <= 16'hfffc;
        else if (ext_bus == EXT_IMM_FD)
            ADDR_OUT <= 16'hfffd;
        else if (ext_bus == EXT_IMM_FE)
            ADDR_OUT <= 16'hfffe;
        else if (ext_bus == EXT_IMM_FF)
            ADDR_OUT <= 16'hffff;

        if (ext_db == EXT_DB_ALU)
            WRITE_DATA_OUT <= alu;
        else if (ext_db == EXT_DB_PCH)
            WRITE_DATA_OUT <= pc[15:8];
        else if (ext_db == EXT_DB_PCL)
            WRITE_DATA_OUT <= pc[7:0];
        else if (ext_db == EXT_DB_P)
            WRITE_DATA_OUT <= p;

        READ_ENABLE_OUT  <= ext_read;
        WRITE_ENABLE_OUT <= ext_write;
    end else begin
        READ_ENABLE_OUT  <= 0;
        WRITE_ENABLE_OUT <= 0;
    end
end


// Registers
logic a_load_alu, a_load_x, a_load_y;
logic x_load_a, x_load_s;
logic y_load_a;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        a <= 0;
        x <= 0;
        y <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (a_load_alu)
            a <= alu;
        else if (a_load_x)
            a <= x;
        else if (a_load_y)
            a <= y;
        if (x_load_a)
            x <= a;
        else if (x_load_s)
            x <= s;
        if (y_load_a)
            y <= a;
    end
end


// Status register
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        p <= 0;
    end else if (CLK_ENABLE_IN) begin
    end
end


// Stack pointer
logic s_load_x;
logic s_dec;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        s <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (s_load_x)
            s <= x;
        else if (s_dec)
            s <= s - 1;
    end
end


// Address bus latch
logic adh_load_ext, adl_load_ext;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        adh <= 0;
        adl <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (adh_load_ext)
            adh <= READ_DATA_IN;
        if (adl_load_ext)
            adl <= READ_DATA_IN;
    end
end


// Program counter
logic pc_inc;
logic pcl_load_ext, pcl_load_adl, pch_load_ext;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        pc <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (pc_inc)
            pc <= pc + 1;

        if (pcl_load_ext)
            pc[7:0] <= READ_DATA_IN;
        else if (pcl_load_adl)
            pc[7:0] <= adl;

        if (pch_load_ext)
            pc[15:8] <= READ_DATA_IN;
    end
end


// ALU
typedef enum {
    ALU_EXT,
    ALU_ADD,
    ALU_ADD_INC
} alu_mode_t;
alu_mode_t alu_mode;

always_comb begin
    alu = 0;
    if (alu_mode == ALU_EXT)
        alu = READ_DATA_IN;
    else if (alu_mode == ALU_ADD)
        alu = add;
    else if (alu_mode == ALU_ADD_INC)
        alu = add + 1;
`ifdef SIMULATION
    else
        $error("alu_mode: unknown mode: %0s", alu_mode);
`endif
end

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        add <= 0;
    else if (CLK_ENABLE_IN)
        add <= alu;


// Interrupts
// System reset interrupt
logic int_reset, int_reset_clear;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        int_reset <= 1;
    else if (INT_RESET_IN)
        int_reset <= 1;
    else if (CLK_ENABLE_IN & int_reset_clear)
        int_reset <= 0;

// The NMI input is edge-sensitive (reacts to high-to-low transitions in the signal)
logic prev_nmi;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        prev_nmi <= 0;
    else if (CLK_ENABLE_IN)
        prev_nmi <= INT_NMI_IN;

// Stays high until the NMI has been handled
logic int_nmi, int_nmi_clear;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        int_nmi <= 0;
    else if (INT_NMI_IN & ~prev_nmi)
        int_nmi <= 1;
    else if (CLK_ENABLE_IN & int_nmi_clear)
        int_nmi <= 0;

// The IRQ input is level-sensitive (reacts to a low signal level)
logic int_irq;
assign int_irq = ~INT_IRQ_IN;


// Microcode processor
typedef enum logic [7:0] {
    OP_ADC_IMM   = 8'h69,
    OP_ADC_ZP    = 8'h65,
    OP_ADC_ZP_X  = 8'h75,
    OP_ADC_ABS   = 8'h6D,
    OP_ADC_ABS_X = 8'h7D,
    OP_ADC_ABS_Y = 8'h79,
    OP_ADC_IND_X = 8'h61,
    OP_ADC_IND_Y = 8'h71,

    OP_AND_IMM   = 8'h29,
    OP_AND_ZP    = 8'h25,
    OP_AND_ZP_X  = 8'h35,
    OP_AND_ABS   = 8'h2D,
    OP_AND_ABS_X = 8'h3D,
    OP_AND_ABS_Y = 8'h39,
    OP_AND_IND_X = 8'h21,
    OP_AND_IND_Y = 8'h31,

    OP_ASL_ACC   = 8'h0A,
    OP_ASL_ZP    = 8'h06,
    OP_ASL_ZP_X  = 8'h16,
    OP_ASL_ABS   = 8'h0E,
    OP_ASL_ABS_X = 8'h1E,

    OP_BCC_REL   = 8'h90,
    OP_BCS_REL   = 8'hB0,
    OP_BEQ_REL   = 8'hF0,
    OP_BIT_ZP    = 8'h24,
    OP_BIT_ABS   = 8'h2C,
    OP_BMI_REL   = 8'h30,
    OP_BNE_REL   = 8'hD0,
    OP_BPL_REL   = 8'h10,
    OP_BRK       = 8'h00,
    OP_BVC_REL   = 8'h50,
    OP_BVS_REL   = 8'h70,
    OP_CLC       = 8'h18,
    OP_CLD       = 8'hD8,
    OP_CLI       = 8'h58,
    OP_CLV       = 8'hB8,

    OP_CMP_IMM   = 8'hC9,
    OP_CMP_ZP    = 8'hC5,
    OP_CMP_ZP_X  = 8'hD5,
    OP_CMP_ABS   = 8'hCD,
    OP_CMP_ABS_X = 8'hDD,
    OP_CMP_ABS_Y = 8'hD9,
    OP_CMP_IND_X = 8'hC1,
    OP_CMP_IND_Y = 8'hD1,

    OP_CPX_IMM   = 8'hE0,
    OP_CPX_ZP    = 8'hE4,
    OP_CPX_ABS   = 8'hEC,
    OP_CPY_IMM   = 8'hC0,
    OP_CPY_ZP    = 8'hC4,
    OP_CPY_ABS   = 8'hCC,

    OP_DEC_ZP    = 8'hC6,
    OP_DEC_ZP_X  = 8'hD6,
    OP_DEC_ABS   = 8'hCE,
    OP_DEC_ABS_X = 8'hDE,
    OP_DEX       = 8'hCA,
    OP_DEY       = 8'h88,

    OP_EOR_IMM   = 8'h49,
    OP_EOR_ZP    = 8'h45,
    OP_EOR_ZP_X  = 8'h55,
    OP_EOR_ABS   = 8'h4D,
    OP_EOR_ABS_X = 8'h5D,
    OP_EOR_ABS_Y = 8'h59,
    OP_EOR_IND_X = 8'h41,
    OP_EOR_IND_Y = 8'h51,

    OP_INC_ZP    = 8'hE6,
    OP_INC_ZP_X  = 8'hF6,
    OP_INC_ABS   = 8'hEE,
    OP_INC_ABS_X = 8'hFE,
    OP_INX       = 8'hE8,
    OP_INY       = 8'hC8,

    OP_JMP_ABS   = 8'h4C,
    OP_JMP_IND   = 8'h6C,
    OP_JSR_ABS   = 8'h20,

    OP_LDA_IMM   = 8'hA9,
    OP_LDA_ZP    = 8'hA5,
    OP_LDA_ZP_X  = 8'hB5,
    OP_LDA_ABS   = 8'hAD,
    OP_LDA_ABS_X = 8'hBD,
    OP_LDA_ABS_Y = 8'hB9,
    OP_LDA_IND_X = 8'hA1,
    OP_LDA_IND_Y = 8'hB1,

    OP_LDX_IMM   = 8'hA2,
    OP_LDX_ZP    = 8'hA6,
    OP_LDX_ZP_Y  = 8'hB6,
    OP_LDX_ABS   = 8'hAE,
    OP_LDX_ABS_Y = 8'hBE,

    OP_LDY_IMM   = 8'hA0,
    OP_LDY_ZP    = 8'hA4,
    OP_LDY_ZP_X  = 8'hB4,
    OP_LDY_ABS   = 8'hAC,
    OP_LDY_ABS_X = 8'hBC,

    OP_LSR_ACC   = 8'h4A,
    OP_LSR_ZP    = 8'h46,
    OP_LSR_ZP_X  = 8'h56,
    OP_LSR_ABS   = 8'h4E,
    OP_LSR_ABS_X = 8'h5E,

    OP_ORA_IMM   = 8'h09,
    OP_ORA_ZP    = 8'h05,
    OP_ORA_ZP_X  = 8'h15,
    OP_ORA_ABS   = 8'h0D,
    OP_ORA_ABS_X = 8'h1D,
    OP_ORA_ABS_Y = 8'h19,
    OP_ORA_IND_X = 8'h01,
    OP_ORA_IND_Y = 8'h11,

    OP_PHA       = 8'h48,
    OP_PHP       = 8'h08,
    OP_PLA       = 8'h68,
    OP_PLP       = 8'h28,

    OP_ROL_ACC   = 8'h2A,
    OP_ROL_ZP    = 8'h26,
    OP_ROL_ZP_X  = 8'h36,
    OP_ROL_ABS   = 8'h2E,
    OP_ROL_ABS_X = 8'h3E,

    OP_ROR_ACC   = 8'h6A,
    OP_ROR_ZP    = 8'h66,
    OP_ROR_ZP_X  = 8'h76,
    OP_ROR_ABS   = 8'h6E,
    OP_ROR_ABS_X = 8'h7E,

    OP_RTI       = 8'h40,
    OP_RTS       = 8'h60,

    OP_SBC_IMM   = 8'hE9,
    OP_SBC_ZP    = 8'hE5,
    OP_SBC_ZP_X  = 8'hF5,
    OP_SBC_ABS   = 8'hED,
    OP_SBC_ABS_X = 8'hFD,
    OP_SBC_ABS_Y = 8'hF9,
    OP_SBC_IND_X = 8'hE1,
    OP_SBC_IND_Y = 8'hF1,

    OP_SEC       = 8'h38,
    OP_SED       = 8'hF8,
    OP_SEI       = 8'h78,

    OP_STA_ZP    = 8'h85,
    OP_STA_ZP_X  = 8'h95,
    OP_STA_ABS   = 8'h8D,
    OP_STA_ABS_X = 8'h9D,
    OP_STA_ABS_Y = 8'h99,
    OP_STA_IND_X = 8'h81,
    OP_STA_IND_Y = 8'h91,

    OP_STX_ZP    = 8'h86,
    OP_STX_ZP_Y  = 8'h96,
    OP_STX_ABS   = 8'h8E,

    OP_STY_ZP    = 8'h84,
    OP_STY_ZP_X  = 8'h94,
    OP_STY_ABS   = 8'h8C,

    OP_TAX       = 8'hAA,
    OP_TAY       = 8'hA8,
    OP_TSX       = 8'hBA,
    OP_TXA       = 8'h8A,
    OP_TXS       = 8'h9A,
    OP_TYA       = 8'h98,

    OP_NOP       = 8'hEA
} op_t;
`ifdef SIMULATION
op_t op;
`else
u8_t op;
`endif
assign op = READ_DATA_IN;

typedef enum {
    MOP_INT_RESET,
    MOP_INT_PCH_PUSH,
    MOP_INT_PCL_PUSH,
    MOP_INT_P_PUSH,
    MOP_INT_PCL_FETCH,
    MOP_INT_PCH_FETCH,
    MOP_PC_FETCH,
    MOP_LOAD_IMM,
    MOP_TXFR,
    MOP_LOAD_A,
    MOP_LOAD_ABS_L,
    MOP_LOAD_ABS_H,
    MOP_LOAD_AD,
    MOP_WRITE_ABS_WB,
    MOP_WRITE_ABS_ALU
} mop_t;
mop_t mop, mop_next;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        mop <= MOP_INT_RESET;
    else if (CLK_ENABLE_IN)
        mop <= mop_next;

// Current op being processed
`ifdef SIMULATION
op_t cop;
`else
u8_t cop;
`endif
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        cop <= OP_NOP;
    else if (CLK_ENABLE_IN && mop == MOP_PC_FETCH)
        cop <= op;

always_comb begin
    int_reset_clear = 0;
    int_nmi_clear   = 0;

    ext_bus         = EXT_PC;
    ext_db          = EXT_DB_ALU;
    ext_read        = 0;
    ext_write       = 0;

    adh_load_ext    = 0;
    adl_load_ext    = 0;

    alu_mode        = ALU_ADD;

    a_load_alu      = 0;
    a_load_x        = 0;
    a_load_y        = 0;
    x_load_a        = 0;
    x_load_s        = 0;
    y_load_a        = 0;
    s_dec           = 0;
    s_load_x        = 0;

    pc_inc          = 0;
    pcl_load_ext    = 0;
    pcl_load_adl    = 0;
    pch_load_ext    = 0;

    mop_next        = mop;

    if (mop == MOP_INT_RESET) begin
        mop_next        = MOP_INT_PCH_PUSH;
    end

    if (mop == MOP_INT_PCH_PUSH) begin
        // EXT {'h01, S} = PCH
        ext_bus         = EXT_S;
        ext_db          = EXT_DB_PCH;
        ext_write       = 1;
        // S = S -1
        s_dec           = 1;
        mop_next        = MOP_INT_PCL_PUSH;
    end

    if (mop == MOP_INT_PCL_PUSH) begin
        // EXT {'h01, S} = PCL
        ext_bus         = EXT_S;
        ext_db          = EXT_DB_PCL;
        ext_write       = 1;
        // S = S -1
        s_dec           = 1;
        mop_next        = MOP_INT_P_PUSH;
    end

    if (mop == MOP_INT_P_PUSH) begin
        // EXT {'h01, S} = P
        ext_bus         = EXT_S;
        ext_db          = EXT_DB_P;
        ext_write       = 1;
        // S = S -1
        s_dec           = 1;
        mop_next        = MOP_INT_PCL_FETCH;
    end

    if (mop == MOP_INT_PCL_FETCH) begin
        // PCL = EXT 'hfffc
        ext_bus         = EXT_IMM_FC;
        ext_read        = 1;
        pcl_load_ext    = 1;
        mop_next        = MOP_INT_PCH_FETCH;
    end

    if (mop == MOP_INT_PCH_FETCH) begin
        // PCH = EXT 'hfffd
        ext_bus         = EXT_IMM_FD;
        ext_read        = 1;
        pch_load_ext    = 1;
        int_reset_clear = 1;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_PC_FETCH) begin
        // Instruction OP fetch cycle
        // PC = PC + 1
        pc_inc          = 1;
        // OP = EXT PC
        ext_bus         = EXT_PC;
        ext_read        = 1;

        if (op == OP_LDA_IMM)
            mop_next    = MOP_LOAD_IMM;
        else if (op == OP_TAX || op == OP_TAY || op == OP_TSX || op == OP_TXA || op == OP_TXS || op == OP_TYA)
            mop_next    = MOP_TXFR;
        else if (op == OP_INC_ABS || op == OP_DEC_ABS)
            mop_next    = MOP_LOAD_ABS_L;
        else if (op == OP_JMP_ABS)
            mop_next    = MOP_LOAD_ABS_L;
    end

    if (mop == MOP_LOAD_IMM) begin
        // PC = PC + 1
        pc_inc          = 1;
        // ALU = EXT PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        alu_mode        = ALU_EXT;

        // REG.A = ALU
        a_load_alu      = cop == OP_LDA_IMM;
        //  || op == OP_LDA_ZP || op == OP_LDA_ZP_X ||
        //                   op == OP_LDA_ABS || op == OP_LDA_ABS_X || op == OP_LDA_ABS_Y ||
        //                   op == OP_LDA_IND_X || op == OP_LDA_IND_Y

        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_TXFR) begin
        // REG.A = X
        a_load_x        = cop == OP_TXA;
        // REG.A = Y
        a_load_y        = cop == OP_TYA;
        // REG.X = A
        x_load_a        = cop == OP_TAX;
        // REG.X = S
        x_load_s        = cop == OP_TSX;
        // REG.Y = A
        y_load_a        = cop == OP_TAY;
        // REG.S = X
        s_load_x        = cop == OP_TXS;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_LOAD_ABS_L) begin
        // PC = PC + 1
        pc_inc          = 1;
        // ADL = EXT PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        adl_load_ext    = 1;
        mop_next        = MOP_LOAD_ABS_H;
    end

    if (mop == MOP_LOAD_ABS_H) begin
        // PC = PC + 1
        pc_inc          = 1;
        // ADH = EXT PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        adh_load_ext    = 1;
        mop_next        = MOP_LOAD_AD;

        if (cop == OP_JMP_ABS) begin
            // PC = {EXT, ADL}
            pch_load_ext    = 1;
            pcl_load_adl    = 1;
            mop_next        = MOP_PC_FETCH;
        end
    end

    if (mop == MOP_LOAD_AD) begin
        // ALU = EXT AD
        ext_bus         = EXT_AD;
        ext_read        = 1;
        alu_mode        = ALU_EXT;
        mop_next        = MOP_WRITE_ABS_WB;
    end

    if (mop == MOP_WRITE_ABS_WB) begin
        // EXT AD = ALU
        ext_bus         = EXT_AD;
        ext_db          = EXT_DB_ALU;
        ext_write       = 1;
        alu_mode        = ALU_ADD;
        mop_next        = MOP_WRITE_ABS_ALU;
    end

    if (mop == MOP_WRITE_ABS_ALU) begin
        // ALU = ADD + 1
        alu_mode        = ALU_ADD_INC;
        // EXT AD = ALU
        ext_bus         = EXT_AD;
        ext_db          = EXT_DB_ALU;
        ext_write       = 1;
        mop_next        = MOP_PC_FETCH;
    end
end


// Debug info
`ifdef SIMULATION
typedef struct packed {
    op_t op;
    u16_t pc;
    // u16_t pc_fetch;
    // u16_t pc_update;
} debug_t;
debug_t debug;

initial begin
    forever begin
        if (mop == MOP_INT_RESET) begin
            debug.op = OP_BRK;
            debug.pc = 'hfffc;
        end

        // if (mop == MOP_INT_PCL_FETCH) begin
        //     debug.pc_fetch = sys_addr;
        //     @(posedge CLK_ENABLE_IN);
        //     debug.pc_update[7:0] = sys_data;
        // end

        // if (mop == MOP_INT_PCH_FETCH) begin
        //     @(posedge CLK_ENABLE_IN);
        //     debug.pc_update[15:8] = sys_data;
        // end

        if (mop == MOP_PC_FETCH) begin
            @(posedge CLK_ENABLE_IN);
            debug.pc = pc;
            debug.op = READ_DATA_IN;
        end

        @(negedge CLK_ENABLE_IN);
        @(posedge CLK);
    end
end
`endif


endmodule
