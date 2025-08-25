module MOS6502 (
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
typedef logic [15:0] u16_t;
typedef logic [7:0]  u8_t;
typedef logic [8:0]  alu_t;     // With carry bit

u8_t adh, adl;

// Registers
u16_t pc;
u8_t a, x, y, s;
alu_t alu, add;

typedef struct packed {
    logic n, v, o, b, d, i, z, c;
} flag_t;
flag_t p;

// External bus
typedef enum {
    EXT_PC,
    EXT_AD,
    EXT_ADL_ZP,
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
    EXT_DB_A,
    EXT_DB_X,
    EXT_DB_Y,
    EXT_DB_P,
    EXT_DB_P_B
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
        if (ext_bus == EXT_ADL_ZP)
            ADDR_OUT <= {8'h00, adl};
        if (ext_bus == EXT_AD)
            ADDR_OUT <= {adh, adl};
        if (ext_bus == EXT_S)
            ADDR_OUT <= {8'h01, s};
        if (ext_bus == EXT_IMM_FA)
            ADDR_OUT <= 16'hfffa;
        if (ext_bus == EXT_IMM_FB)
            ADDR_OUT <= 16'hfffb;
        if (ext_bus == EXT_IMM_FC)
            ADDR_OUT <= 16'hfffc;
        if (ext_bus == EXT_IMM_FD)
            ADDR_OUT <= 16'hfffd;
        if (ext_bus == EXT_IMM_FE)
            ADDR_OUT <= 16'hfffe;
        if (ext_bus == EXT_IMM_FF)
            ADDR_OUT <= 16'hffff;

        if (ext_write) begin
            if (ext_db == EXT_DB_ALU)
                WRITE_DATA_OUT <= alu[7:0];
            if (ext_db == EXT_DB_PCH)
                WRITE_DATA_OUT <= pc[15:8];
            if (ext_db == EXT_DB_PCL)
                WRITE_DATA_OUT <= pc[7:0];
            if (ext_db == EXT_DB_A)
                WRITE_DATA_OUT <= a;
            if (ext_db == EXT_DB_X)
                WRITE_DATA_OUT <= x;
            if (ext_db == EXT_DB_Y)
                WRITE_DATA_OUT <= y;
            if (ext_db == EXT_DB_P)
                WRITE_DATA_OUT <= p;
            if (ext_db == EXT_DB_P_B)
                WRITE_DATA_OUT <= p | ('h01 << 4);
        end

        READ_ENABLE_OUT  <= ext_read;
        WRITE_ENABLE_OUT <= ext_write;
    end else begin
        READ_ENABLE_OUT  <= 0;
        WRITE_ENABLE_OUT <= 0;
    end
end


// Registers
logic a_load_alu, a_load_x, a_load_y;
logic x_load_alu, x_load_a, x_load_s;
logic y_load_alu, y_load_a;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        a <= 0;
        x <= 0;
        y <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (a_load_alu)
            a <= alu[7:0];
        else if (a_load_x)
            a <= x;
        else if (a_load_y)
            a <= y;
        if (x_load_alu)
            x <= alu[7:0];
        else if (x_load_a)
            x <= a;
        else if (x_load_s)
            x <= s;
        if (y_load_alu)
            y <= alu[7:0];
        else if (y_load_a)
            y <= a;
    end
end


// Status register
flag_t p_update, p_value;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        p <= 0;
        p.o <= 1;
    end else if (CLK_ENABLE_IN) begin
        p <= (~p_update & p) | (p_update & p_value);
        p.o <= 1;
    end
end


// Stack pointer
logic s_load_x;
logic s_inc, s_dec;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        s <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (s_load_x)
            s <= x;
        else if (s_dec)
            s <= s - 1;
        else if (s_inc)
            s <= s + 1;
    end
end


// Address bus latch
logic adh_load_ext, adh_load_alu, adh_load_zp, adh_load_stack;
logic adl_load_ext, adl_load_alu, adl_inc;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        adh <= 0;
        adl <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (adh_load_ext)
            adh <= READ_DATA_IN;
        else if (adh_load_alu)
            adh <= alu;
        else if (adh_load_zp)
            adh <= 0;
        else if (adh_load_stack)
            adh <= 1;
        if (adl_load_ext)
            adl <= READ_DATA_IN;
        else if (adl_load_alu)
            adl <= alu[7:0];
        else if (adl_inc)
            adl <= adl + 1;
    end
end


// Program counter
logic pc_inc;
logic pch_load_ext, pch_inc, pch_dec;
logic pcl_load_ext, pcl_load_adl, pcl_load_alu;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        pc <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (pc_inc)
            pc <= pc + 1;

        if (pch_load_ext)
            pc[15:8] <= READ_DATA_IN;
        if (pch_inc)
            pc[15:8] <= pc[15:8] + 1;
        if (pch_dec)
            pc[15:8] <= pc[15:8] - 1;

        if (pcl_load_ext)
            pc[7:0] <= READ_DATA_IN;
        else if (pcl_load_alu)
            pc[7:0] <= alu;
        else if (pcl_load_adl)
            pc[7:0] <= adl;
    end
end


// ALU
typedef enum {
    ALU_EXT,
    ALU_A_AND_EXT,
    ALU_A_OR_EXT,
    ALU_A_XOR_EXT,
    ALU_A_ADD_EXT_C,
    ALU_A_SUB_EXT_C,
    ALU_A_SUB_EXT,
    ALU_X_SUB_EXT,
    ALU_Y_SUB_EXT,
    ALU_ADD,
    ALU_ADD_INC,
    ALU_ADD_DEC,
    ALU_ADD_SL,
    ALU_ADD_SR,
    ALU_ADD_SL_C,
    ALU_ADD_SR_C,
    ALU_ADD_X,
    ALU_ADD_Y,
    ALU_ADD_PCL,
    ALU_ADH_C,
    ALU_A,
    ALU_X_INC,
    ALU_X_DEC,
    ALU_Y_INC,
    ALU_Y_DEC
} alu_mode_t;
alu_mode_t alu_mode;

always_comb begin
    alu = add;
    if (alu_mode == ALU_EXT)
        alu = READ_DATA_IN;
    if (alu_mode == ALU_A_AND_EXT)
        alu = a & READ_DATA_IN;
    if (alu_mode == ALU_A_OR_EXT)
        alu = a | READ_DATA_IN;
    if (alu_mode == ALU_A_XOR_EXT)
        alu = a ^ READ_DATA_IN;
    if (alu_mode == ALU_A_ADD_EXT_C)
        alu = a + READ_DATA_IN + p.c;
    if (alu_mode == ALU_A_SUB_EXT_C)
        alu = a + 8'(~READ_DATA_IN) + p.c;
        // alu = (a - READ_DATA_IN - ~p.c) ^ 'h100;
    if (alu_mode == ALU_A_SUB_EXT)
        alu = a + 8'(~READ_DATA_IN) + 1;
        // alu = (a - READ_DATA_IN) ^ 'h100;
    if (alu_mode == ALU_X_SUB_EXT)
        alu = x + 8'(~READ_DATA_IN) + 1;
        // alu = (x - READ_DATA_IN) ^ 'h100;
    if (alu_mode == ALU_Y_SUB_EXT)
        alu = y + 8'(~READ_DATA_IN) + 1;
        // alu = (y - READ_DATA_IN) ^ 'h100;
    if (alu_mode == ALU_ADD)
        alu = add;
    if (alu_mode == ALU_ADD_INC)
        alu = add + 1;
    if (alu_mode == ALU_ADD_DEC)
        alu = add - 1;
    if (alu_mode == ALU_ADD_SL)
        alu = {add[7:0], 1'b0};
    if (alu_mode == ALU_ADD_SR)
        alu = {add[0], 1'b0, add[7:1]};
    if (alu_mode == ALU_ADD_SL_C)
        alu = {add[7:0], p.c};
    if (alu_mode == ALU_ADD_SR_C)
        alu = {add[0], p.c, add[7:1]};
    if (alu_mode == ALU_ADD_X)
        alu = add + x;
    if (alu_mode == ALU_ADD_Y)
        alu = add + y;
    if (alu_mode == ALU_ADD_PCL)
        alu = add + pc[7:0];
    if (alu_mode == ALU_A)
        alu = a;
    if (alu_mode == ALU_X_INC)
        alu = x + 1;
    if (alu_mode == ALU_X_DEC)
        alu = x - 1;
    if (alu_mode == ALU_Y_INC)
        alu = y + 1;
    if (alu_mode == ALU_Y_DEC)
        alu = y - 1;
    if (alu_mode == ALU_ADH_C)
        alu = adh + add[8];
end

flag_t alu_p_value;
logic alu_p_pcl_ovf;
always_comb begin
    u8_t alu_a, alu_b;
    alu_p_value = 0;
    alu_p_value.c = alu[8];
    alu_p_value.z = alu[7:0] == 0;
    alu_p_value.n = alu[7];
    // Overflow flags
    alu_a = a;
    alu_b = alu_mode == ALU_A_ADD_EXT_C ? READ_DATA_IN : ~READ_DATA_IN;
    // Set when sign(A) == sign(B) && sign(A) != sign(ALU)
    alu_p_value.v = (alu_a[7] == alu_b[7]) && (alu_a[7] != alu[7]);
    // Unsigned ADD + signed PCL
    alu_p_pcl_ovf = add[7] ^ alu[8];
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

typedef enum {
    MOP_INT_RESET,
    MOP_INT_PCH_PUSH,
    MOP_INT_PCL_PUSH,
    MOP_INT_P_PUSH,
    MOP_INT_PCL_FETCH,
    MOP_INT_PCH_FETCH,
    MOP_PC_FETCH,
    MOP_NOP,
    MOP_PUSH_A,
    MOP_POP_S,
    MOP_POP_REG,
    MOP_LOAD_A,
    MOP_LOAD,
    MOP_LOAD_H_FIX,
    MOP_IMM_NOP,
    MOP_ZP,
    MOP_ZP_LOAD,
    MOP_ZP_IND,
    MOP_ZP_IND_L,
    MOP_ZP_IND_H,
    MOP_ABS_L,
    MOP_ABS_H,
    MOP_WRITE_BACK,
    MOP_WRITE_ALU,
    MOP_WRITE_REG,
    MOP_JSR_NOP,
    MOP_IND_JMP_L,
    MOP_IND_JMP_H,
    MOP_RTS_LOAD,
    MOP_RTS_POP_S,
    MOP_RTS_POP_PCL,
    MOP_RTS_POP_PCH,
    MOP_REL_CHECK,
    MOP_REL_TAKEN,
    MOP_REL_H_FIX,
    MOP_TXFR,
    MOP_ALU,
    MOP_BIT,
    MOP_FLAGS
} mop_t;
mop_t mop, mop_next;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        mop <= MOP_INT_RESET;
    else if (CLK_ENABLE_IN)
        mop <= mop_next;

`ifdef SIMULATION
mop_t mop_last;
logic mop_error;
always_ff @(posedge CLK) begin
    if (CLK_ENABLE_IN) begin
        mop_last <= mop;
        mop_error <= 0;
        if (mop == MOP_PC_FETCH && mop_last == MOP_PC_FETCH) begin
            mop_error <= 1;
            $error("Unknown instruction");
        end
    end
end
`endif

// Current op being processed
op_t cop;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        cop <= OP_NOP;
    end else if (CLK_ENABLE_IN) begin
        if (mop == MOP_PC_FETCH)
            cop <= op_t'(READ_DATA_IN);
        if (mop == MOP_INT_RESET)
            cop <= OP_NOP;
    end
end

always_comb begin
    int_reset_clear = 0;
    int_nmi_clear   = 0;

    ext_bus         = EXT_PC;
    ext_db          = EXT_DB_A;
    ext_read        = 0;
    ext_write       = 0;

    adh_load_ext    = 0;
    adh_load_alu    = 0;
    adh_load_zp     = 0;
    adh_load_stack  = 0;
    adl_load_ext    = 0;
    adl_load_alu    = 0;
    adl_inc         = 0;

    alu_mode        = ALU_ADD;

    a_load_alu      = 0;
    a_load_x        = 0;
    a_load_y        = 0;
    x_load_alu      = 0;
    x_load_a        = 0;
    x_load_s        = 0;
    y_load_alu      = 0;
    y_load_a        = 0;
    s_inc           = 0;
    s_dec           = 0;
    s_load_x        = 0;

    p_update        = 0;
    p_value         = 0;

    pc_inc          = 0;
    pch_load_ext    = 0;
    pch_inc         = 0;
    pch_dec         = 0;
    pcl_load_ext    = 0;
    pcl_load_alu    = 0;
    pcl_load_adl    = 0;

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
        if (cop == OP_JSR_ABS)
            mop_next    = MOP_ABS_H;
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
        op_t op;
        op = op_t'(READ_DATA_IN);

        // PC = PC + 1
        pc_inc          = 1;
        // OP = EXT PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        // ALU = A
        alu_mode        = ALU_A;

        if (op == OP_TAX || op == OP_TAY || op == OP_TSX || op == OP_TXA || op == OP_TXS || op == OP_TYA)
            mop_next = MOP_TXFR;
        if (op == OP_INX || op == OP_DEX || op == OP_INY || op == OP_DEY ||
            op == OP_ASL_ACC || op == OP_LSR_ACC || op == OP_ROL_ACC || op == OP_ROR_ACC)
            mop_next = MOP_ALU;
        if (op == OP_CLC || op == OP_CLD || op == OP_CLI || op == OP_CLV ||
            op == OP_SEC || op == OP_SED || op == OP_SEI)
            mop_next = MOP_FLAGS;
        if (op == OP_NOP ||
            op == OP_PHA || op == OP_PHP || op == OP_PLA || op == OP_PLP)
            mop_next = MOP_NOP;
        if (op == OP_LDA_IMM || op == OP_LDX_IMM || op == OP_LDY_IMM ||
            op == OP_CMP_IMM || op == OP_CPX_IMM || op == OP_CPY_IMM ||
            op == OP_AND_IMM || op == OP_ORA_IMM || op == OP_EOR_IMM ||
            op == OP_ADC_IMM || op == OP_SBC_IMM)
            mop_next = MOP_LOAD;
        if (op == OP_LDA_ZP || op == OP_LDA_ZP_X ||
            op == OP_LDX_ZP || op == OP_LDX_ZP_Y ||
            op == OP_LDY_ZP || op == OP_LDY_ZP_X ||
            op == OP_CMP_ZP || op == OP_CMP_ZP_X || op == OP_CPX_ZP || op == OP_CPY_ZP ||
            op == OP_LDA_IND_Y ||
            op == OP_INC_ZP || op == OP_DEC_ZP ||
            op == OP_INC_ZP_X || op == OP_DEC_ZP_X ||
            op == OP_ASL_ZP || op == OP_LSR_ZP || op == OP_ROL_ZP || op == OP_ROR_ZP ||
            op == OP_ASL_ZP_X || op == OP_LSR_ZP_X || op == OP_ROL_ZP_X || op == OP_ROR_ZP_X ||
            op == OP_AND_ZP || op == OP_ORA_ZP || op == OP_EOR_ZP ||
            op == OP_AND_ZP_X || op == OP_ORA_ZP_X || op == OP_EOR_ZP_X ||
            op == OP_ADC_ZP || op == OP_SBC_ZP ||
            op == OP_ADC_ZP_X || op == OP_SBC_ZP_X ||
            op == OP_BIT_ZP ||
            op == OP_STA_ZP || op == OP_STX_ZP || op == OP_STY_ZP ||
            op == OP_STA_ZP_X || op == OP_STX_ZP_Y || op == OP_STY_ZP_X ||
            op == OP_STA_IND_Y)
            mop_next = MOP_ZP;
        if (op == OP_LDA_ABS || op == OP_LDA_ABS_X || op == OP_LDA_ABS_Y ||
            op == OP_LDX_ABS || op == OP_LDX_ABS_Y ||
            op == OP_LDY_ABS || op == OP_LDY_ABS_X ||
            op == OP_AND_ABS || op == OP_AND_ABS_X || op == OP_AND_ABS_Y ||
            op == OP_ORA_ABS || op == OP_ORA_ABS_X || op == OP_ORA_ABS_Y ||
            op == OP_EOR_ABS || op == OP_EOR_ABS_X || op == OP_EOR_ABS_Y ||
            op == OP_ADC_ABS || op == OP_ADC_ABS_X || op == OP_ADC_ABS_Y ||
            op == OP_SBC_ABS || op == OP_SBC_ABS_X || op == OP_SBC_ABS_Y ||
            op == OP_BIT_ABS || op == OP_CPX_ABS || op == OP_CPY_ABS ||
            op == OP_CMP_ABS || op == OP_CMP_ABS_X || op == OP_CMP_ABS_Y ||
            op == OP_INC_ABS || op == OP_DEC_ABS ||
            op == OP_ASL_ABS || op == OP_LSR_ABS ||
            op == OP_ROL_ABS || op == OP_ROR_ABS ||
            op == OP_STA_ABS || op == OP_STA_ABS_X || op == OP_STA_ABS_Y ||
            op == OP_STX_ABS || op == OP_STY_ABS ||
            op == OP_JMP_ABS || op == OP_JMP_IND || op == OP_JSR_ABS)
            mop_next = MOP_ABS_L;
        if (op == OP_BCC_REL || op == OP_BCS_REL || op == OP_BNE_REL || op == OP_BEQ_REL ||
            op == OP_BPL_REL || op == OP_BMI_REL || op == OP_BVC_REL || op == OP_BVS_REL)
            mop_next = MOP_REL_CHECK;
        if (op == OP_RTS)
            mop_next = MOP_RTS_LOAD;
    end

    if (mop == MOP_IMM_NOP) begin
        // PC = PC + 1
        pc_inc          = 1;
        // Read EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_NOP) begin
        // Read EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        mop_next        = MOP_PC_FETCH;
        if (cop == OP_PHA || cop == OP_PHP)
            mop_next    = MOP_PUSH_A;
        if (cop == OP_PLA || cop == OP_PLP)
            mop_next    = MOP_POP_S;
    end

    if (mop == MOP_PUSH_A) begin
        // EXT.S = REG
        ext_bus         = EXT_S;
        ext_db          = cop == OP_PHP ? EXT_DB_P_B : EXT_DB_A;
        ext_write       = 1;
        // S = S - 1
        s_dec           = 1;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_POP_S) begin
        // S = S + 1
        s_inc           = 1;
        mop_next        = MOP_POP_REG;
    end

    if (mop == MOP_POP_REG) begin
        // ALU = EXT.S
        ext_bus         = EXT_S;
        ext_read        = 1;
        alu_mode        = ALU_EXT;
        a_load_alu      = cop == OP_PLA;
        p_update        = cop == OP_PLP ? 'hcf : 'h00;
        p_value         = READ_DATA_IN;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_LOAD) begin
        // ALU = EXT.AD
        ext_bus         = EXT_AD;
        ext_read        = 1;
        if (cop == OP_LDA_IMM || cop == OP_LDX_IMM || cop == OP_LDY_IMM ||
            cop == OP_CMP_IMM || cop == OP_CPX_IMM || cop == OP_CPY_IMM ||
            cop == OP_AND_IMM || cop == OP_ORA_IMM || cop == OP_EOR_IMM ||
            cop == OP_ADC_IMM || cop == OP_SBC_IMM) begin
            // PC = PC + 1
            pc_inc      = 1;
            // ALU = EXT.PC
            ext_bus     = EXT_PC;
            ext_read    = 1;
        end
        // REG.A = ALU
        a_load_alu      = 1;
        // ALU operation
        alu_mode        = ALU_EXT;
        p_value         = alu_p_value;
        p_update.z      = 1;
        p_update.n      = 1;
        if (cop == OP_LDA_IMM || cop == OP_LDA_ZP || cop == OP_LDA_ZP_X || cop == OP_LDA_IND_Y)
            a_load_alu  = 1;
        if (cop == OP_LDA_ABS || cop == OP_LDA_ABS_X || cop == OP_LDA_ABS_Y)
            a_load_alu  = 1;
        if (cop == OP_LDX_IMM || cop == OP_LDX_ZP || cop == OP_LDX_ZP_Y ||
            cop == OP_LDX_ABS || cop == OP_LDX_ABS_Y) begin
            a_load_alu  = 0;
            x_load_alu  = 1;
        end
        if (cop == OP_LDY_IMM || cop == OP_LDY_ZP || cop == OP_LDY_ZP_X ||
            cop == OP_LDY_ABS || cop == OP_LDY_ABS_X) begin
            a_load_alu  = 0;
            y_load_alu  = 1;
        end
        if (cop == OP_CMP_IMM || cop == OP_CMP_ZP || cop == OP_CMP_ZP_X ||
            cop == OP_CMP_ABS || cop == OP_CMP_ABS_X || cop == OP_CMP_ABS_Y) begin
            a_load_alu  = 0;
            alu_mode    = ALU_A_SUB_EXT;
            p_update.c  = 1;
        end
        if (cop == OP_CPX_IMM || cop == OP_CPX_ZP || cop == OP_CPX_ABS) begin
            a_load_alu  = 0;
            alu_mode    = ALU_X_SUB_EXT;
            p_update.c  = 1;
        end
        if (cop == OP_CPY_IMM || cop == OP_CPY_ZP || cop == OP_CPY_ABS) begin
            a_load_alu  = 0;
            alu_mode    = ALU_Y_SUB_EXT;
            p_update.c  = 1;
        end
        if (cop == OP_AND_IMM || cop == OP_AND_ZP || cop == OP_AND_ZP_X ||
            cop == OP_AND_ABS || cop == OP_AND_ABS_X || cop == OP_AND_ABS_Y)
            alu_mode    = ALU_A_AND_EXT;
        if (cop == OP_ORA_IMM || cop == OP_ORA_ZP || cop == OP_ORA_ZP_X ||
            cop == OP_ORA_ABS || cop == OP_ORA_ABS_X || cop == OP_ORA_ABS_Y)
            alu_mode    = ALU_A_OR_EXT;
        if (cop == OP_EOR_IMM || cop == OP_EOR_ZP || cop == OP_EOR_ZP_X ||
            cop == OP_EOR_ABS || cop == OP_EOR_ABS_X || cop == OP_EOR_ABS_Y)
            alu_mode    = ALU_A_XOR_EXT;
        if (cop == OP_ADC_IMM || cop == OP_ADC_ZP || cop == OP_ADC_ZP_X ||
            cop == OP_ADC_ABS || cop == OP_ADC_ABS_X || cop == OP_ADC_ABS_Y) begin
            alu_mode    = ALU_A_ADD_EXT_C;
            p_update.c  = 1;
            p_update.v  = 1;
        end
        if (cop == OP_SBC_IMM || cop == OP_SBC_ZP || cop == OP_SBC_ZP_X ||
            cop == OP_SBC_ABS || cop == OP_SBC_ABS_X || cop == OP_SBC_ABS_Y) begin
            alu_mode    = ALU_A_SUB_EXT_C;
            p_update.c  = 1;
            p_update.v  = 1;
        end
        mop_next    = MOP_PC_FETCH;
        if (cop == OP_ASL_ZP || cop == OP_LSR_ZP || cop == OP_ROL_ZP || cop == OP_ROR_ZP ||
            cop == OP_INC_ZP || cop == OP_DEC_ZP || cop == OP_INC_ZP_X || cop == OP_DEC_ZP_X ||
            cop == OP_ASL_ZP_X || cop == OP_LSR_ZP_X || cop == OP_ROL_ZP_X || cop == OP_ROR_ZP_X ||
            cop == OP_INC_ABS || cop == OP_DEC_ABS ||
            cop == OP_ASL_ABS || cop == OP_LSR_ABS ||
            cop == OP_ROL_ABS || cop == OP_ROR_ABS) begin
            a_load_alu  = 0;
            mop_next    = MOP_WRITE_BACK;
        end
    end

    if (mop == MOP_LOAD_H_FIX) begin
        // Read EXT.AD
        ext_bus             = EXT_AD;
        ext_read            = 1;
        if (add[8]) begin
            // ADH correction needed
            // ALU = ADH + C
            alu_mode        = ALU_ADH_C;
            // ADH = ALU
            adh_load_alu    = 1;
            mop_next        = MOP_LOAD;
        end else begin
            // ADH is correct
            alu_mode        = ALU_EXT;
            p_value         = alu_p_value;
            p_update.z      = 1;
            p_update.n      = 1;
            if (cop == OP_LDA_ABS_X || cop == OP_LDA_ABS_Y || cop == OP_LDA_IND_Y)
                a_load_alu  = 1;
            if (cop == OP_LDX_ABS_Y)
                x_load_alu  = 1;
            if (cop == OP_LDY_ABS_X)
                y_load_alu  = 1;
            if (cop == OP_CMP_ABS_X || cop == OP_CMP_ABS_Y) begin
                alu_mode    = ALU_A_SUB_EXT;
                p_update.c  = 1;
            end
            if (cop == OP_AND_ABS_X || cop == OP_AND_ABS_Y) begin
                alu_mode    = ALU_A_AND_EXT;
                a_load_alu  = 1;
            end
            if (cop == OP_ORA_ABS_X || cop == OP_ORA_ABS_Y) begin
                alu_mode    = ALU_A_OR_EXT;
                a_load_alu  = 1;
            end
            if (cop == OP_EOR_ABS_X || cop == OP_EOR_ABS_Y) begin
                alu_mode    = ALU_A_XOR_EXT;
                a_load_alu  = 1;
            end
            if (cop == OP_ADC_ABS_X || cop == OP_ADC_ABS_Y) begin
                alu_mode    = ALU_A_ADD_EXT_C;
                a_load_alu  = 1;
                p_update.c  = 1;
                p_update.v  = 1;
            end
            if (cop == OP_SBC_ABS_X || cop == OP_SBC_ABS_Y) begin
                alu_mode    = ALU_A_SUB_EXT_C;
                a_load_alu  = 1;
                p_update.c  = 1;
                p_update.v  = 1;
            end
            mop_next        = MOP_PC_FETCH;
        end
        if (cop == OP_STA_ABS_X || cop == OP_STA_ABS_Y || cop == OP_STA_IND_Y) begin
            p_update        = 0;
            mop_next        = MOP_WRITE_REG;
        end
    end

    if (mop == MOP_ZP) begin
        // PC = PC + 1
        pc_inc          = 1;
        // ADH = ZP
        adh_load_zp     = 1;
        // ADL = EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        adl_load_ext    = 1;
        // ALU = EXT.PC
        alu_mode        = ALU_EXT;

        mop_next        = MOP_LOAD;
        if (cop == OP_BIT_ZP)
            mop_next    = MOP_BIT;
        if (cop == OP_STA_ZP || cop == OP_STX_ZP || cop == OP_STY_ZP)
            mop_next    = MOP_WRITE_REG;
        if (cop == OP_LDA_ZP_X || cop == OP_LDX_ZP_Y || cop == OP_LDY_ZP_X ||
            cop == OP_STA_ZP_X || cop == OP_STX_ZP_Y || cop == OP_STY_ZP_X ||
            cop == OP_AND_ZP_X || cop == OP_ORA_ZP_X || cop == OP_EOR_ZP_X ||
            cop == OP_ADC_ZP_X || cop == OP_SBC_ZP_X || cop == OP_CMP_ZP_X ||
            cop == OP_ASL_ZP_X || cop == OP_LSR_ZP_X ||
            cop == OP_ROL_ZP_X || cop == OP_ROR_ZP_X ||
            cop == OP_INC_ZP_X || cop == OP_DEC_ZP_X)
            mop_next    = MOP_ZP_IND;
        if (cop == OP_LDA_IND_Y || cop == OP_STA_IND_Y)
            mop_next    = MOP_ZP_IND_L;
    end

    if (mop == MOP_ZP_IND) begin
        // Read EXT.AD
        ext_bus         = EXT_AD;
        ext_read        = 1;
        // ALU = ADD + REG
        if (cop == OP_LDA_ZP_X || cop == OP_LDY_ZP_X ||
            cop == OP_STA_ZP_X || cop == OP_STY_ZP_X ||
            cop == OP_AND_ZP_X || cop == OP_ORA_ZP_X || cop == OP_EOR_ZP_X ||
            cop == OP_ADC_ZP_X || cop == OP_SBC_ZP_X || cop == OP_CMP_ZP_X ||
            cop == OP_ASL_ZP_X || cop == OP_LSR_ZP_X ||
            cop == OP_ROL_ZP_X || cop == OP_ROR_ZP_X ||
            cop == OP_INC_ZP_X || cop == OP_DEC_ZP_X)
            alu_mode    = ALU_ADD_X;
        if (cop == OP_LDX_ZP_Y || cop == OP_STX_ZP_Y)
            alu_mode    = ALU_ADD_Y;
        // ADL = ALU
        adl_load_alu    = 1;
        mop_next        = MOP_LOAD;
        if (cop == OP_STA_ZP_X || cop == OP_STX_ZP_Y || cop == OP_STY_ZP_X)
            mop_next    = MOP_WRITE_REG;
    end

    if (mop == MOP_ZP_IND_L) begin
        // ALU = EXT.ZP
        ext_bus         = EXT_AD;
        ext_read        = 1;
        alu_mode        = ALU_EXT;
        // ADL = ADL + 1
        adl_inc         = 1;
        mop_next        = MOP_ZP_IND_H;
    end

    if (mop == MOP_ZP_IND_H) begin
        // ADH = EXT.ZP
        ext_bus         = EXT_AD;
        ext_read        = 1;
        adh_load_ext    = 1;
        // ALU = ADD + REG.Y
        alu_mode        = ALU_ADD_Y;
        // ADL = ALU
        adl_load_alu    = 1;
        mop_next        = MOP_LOAD_H_FIX;
    end

    if (mop == MOP_ABS_L) begin
        // PC = PC + 1
        pc_inc          = 1;
        // ADL = EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        adl_load_ext    = 1;
        // ALU = EXT.PC
        alu_mode        = ALU_EXT;
        mop_next        = MOP_ABS_H;
        if (cop == OP_JSR_ABS)
            mop_next    = MOP_JSR_NOP;
    end

    if (mop == MOP_ABS_H) begin
        // PC = PC + 1
        pc_inc          = 1;
        // ADH = EXT PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        adh_load_ext    = 1;
        // ALU = ADD
        alu_mode        = ALU_ADD;
        // ALU = ADD + REG
        if (cop == OP_LDA_ABS_X || cop == OP_LDY_ABS_X ||
            cop == OP_AND_ABS_X || cop == OP_ORA_ABS_X || cop == OP_EOR_ABS_X ||
            cop == OP_ADC_ABS_X || cop == OP_SBC_ABS_X ||
            cop == OP_CMP_ABS_X || cop == OP_STA_ABS_X)
            alu_mode    = ALU_ADD_X;
        if (cop == OP_LDA_ABS_Y || cop == OP_LDX_ABS_Y ||
            cop == OP_AND_ABS_Y || cop == OP_ORA_ABS_Y || cop == OP_EOR_ABS_Y ||
            cop == OP_ADC_ABS_Y || cop == OP_SBC_ABS_Y ||
            cop == OP_CMP_ABS_Y || cop == OP_STA_ABS_Y)
            alu_mode    = ALU_ADD_Y;
        // ADL = ALU
        adl_load_alu    = 1;

        mop_next            = MOP_LOAD;
        if (cop == OP_STA_ABS || cop == OP_STX_ABS || cop == OP_STY_ABS)
            mop_next        = MOP_WRITE_REG;
        if (cop == OP_LDA_ABS_X || cop == OP_LDY_ABS_X ||
            cop == OP_AND_ABS_X || cop == OP_ORA_ABS_X || cop == OP_EOR_ABS_X ||
            cop == OP_ADC_ABS_X || cop == OP_SBC_ABS_X ||
            cop == OP_CMP_ABS_X || cop == OP_STA_ABS_X)
            mop_next        = MOP_LOAD_H_FIX;
        if (cop == OP_LDA_ABS_Y || cop == OP_LDX_ABS_Y ||
            cop == OP_AND_ABS_Y || cop == OP_ORA_ABS_Y || cop == OP_EOR_ABS_Y ||
            cop == OP_ADC_ABS_Y || cop == OP_SBC_ABS_Y ||
            cop == OP_CMP_ABS_Y || cop == OP_STA_ABS_Y)
            mop_next        = MOP_LOAD_H_FIX;
        if (cop == OP_BIT_ABS)
            mop_next        = MOP_BIT;
        if (cop == OP_JMP_IND)
            mop_next        = MOP_IND_JMP_L;
        if (cop == OP_JMP_ABS || cop == OP_JSR_ABS) begin
            // PC = {EXT, ADL}
            pch_load_ext    = 1;
            pcl_load_adl    = 1;
            mop_next        = MOP_PC_FETCH;
        end
    end

    if (mop == MOP_WRITE_BACK) begin
        // EXT.AD = ALU
        ext_bus         = EXT_AD;
        ext_db          = EXT_DB_ALU;
        ext_write       = 1;
        alu_mode        = ALU_ADD;
        mop_next        = MOP_WRITE_ALU;
    end

    if (mop == MOP_WRITE_ALU) begin
        if (cop == OP_INC_ZP || cop == OP_INC_ZP_X || cop == OP_INC_ABS)
            alu_mode    = ALU_ADD_INC;
        if (cop == OP_DEC_ZP || cop == OP_DEC_ZP_X || cop == OP_DEC_ABS)
            alu_mode    = ALU_ADD_DEC;
        if (cop == OP_ASL_ZP || cop == OP_ASL_ZP_X || cop == OP_ASL_ABS) begin
            alu_mode    = ALU_ADD_SL;
            p_update.c  = 1;
        end
        if (cop == OP_LSR_ZP || cop == OP_LSR_ZP_X || cop == OP_LSR_ABS) begin
            alu_mode    = ALU_ADD_SR;
            p_update.c  = 1;
        end
        if (cop == OP_ROL_ZP || cop == OP_ROL_ZP_X || cop == OP_ROL_ABS) begin
            alu_mode    = ALU_ADD_SL_C;
            p_update.c  = 1;
        end
        if (cop == OP_ROR_ZP || cop == OP_ROR_ZP_X || cop == OP_ROR_ABS) begin
            alu_mode    = ALU_ADD_SR_C;
            p_update.c  = 1;
        end

        // EXT.AD = ALU
        ext_bus         = EXT_AD;
        ext_db          = EXT_DB_ALU;
        ext_write       = 1;
        p_update.z      = 1;
        p_update.n      = 1;
        p_value         = alu_p_value;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_WRITE_REG) begin
        // EXT.AD = REG
        ext_bus         = EXT_AD;
        ext_db          = EXT_DB_A;
        ext_write       = 1;
        if (cop == OP_STA_ZP || cop == OP_STA_ZP_X)
            ext_db      = EXT_DB_A;
        if (cop == OP_STA_ABS || cop == OP_STA_ABS_X || cop == OP_STA_ABS_Y)
            ext_db      = EXT_DB_A;
        if (cop == OP_STA_IND_X || cop == OP_STA_IND_Y)
            ext_db      = EXT_DB_A;
        if (cop == OP_STX_ZP || cop == OP_STX_ZP_Y || cop == OP_STX_ABS)
            ext_db      = EXT_DB_X;
        if (cop == OP_STY_ZP || cop == OP_STY_ZP_X || cop == OP_STY_ABS)
            ext_db      = EXT_DB_Y;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_JSR_NOP) begin
        mop_next        = MOP_INT_PCH_PUSH;
    end

    if (mop == MOP_IND_JMP_L) begin
        // PCL = EXT.AD
        ext_bus         = EXT_AD;
        ext_read        = 1;
        pcl_load_ext    = 1;
        // ALU = ADD + 1
        alu_mode        = ALU_ADD_INC;
        // ADL = ALU
        adl_load_alu    = 1;
        mop_next        = MOP_IND_JMP_H;
    end

    if (mop == MOP_IND_JMP_H) begin
        // PCH = EXT.AD
        ext_bus         = EXT_AD;
        ext_read        = 1;
        pch_load_ext    = 1;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_RTS_LOAD) begin
        // Read EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        mop_next        = MOP_RTS_POP_S;
    end

    if (mop == MOP_RTS_POP_S) begin
        // S = S + 1
        s_inc           = 1;
        mop_next        = MOP_RTS_POP_PCL;
    end

    if (mop == MOP_RTS_POP_PCL) begin
        // PCL = EXT.S
        ext_bus         = EXT_S;
        ext_read        = 1;
        pcl_load_ext    = 1;
        // S = S + 1
        s_inc           = 1;
        mop_next        = MOP_RTS_POP_PCH;
    end

    if (mop == MOP_RTS_POP_PCH) begin
        // PCH = EXT.S
        ext_bus         = EXT_S;
        ext_read        = 1;
        pch_load_ext    = 1;
        mop_next        = MOP_IMM_NOP;
    end

    if (mop == MOP_REL_CHECK) begin
        pc_inc          = 1;
        // ALU = EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        alu_mode        = ALU_EXT;
        mop_next        = MOP_PC_FETCH;
        if (cop == OP_BCC_REL && !p.c)
            mop_next    = MOP_REL_TAKEN;
        if (cop == OP_BCS_REL &&  p.c)
            mop_next    = MOP_REL_TAKEN;
        if (cop == OP_BNE_REL && !p.z)
            mop_next    = MOP_REL_TAKEN;
        if (cop == OP_BEQ_REL &&  p.z)
            mop_next    = MOP_REL_TAKEN;
        if (cop == OP_BPL_REL && !p.n)
            mop_next    = MOP_REL_TAKEN;
        if (cop == OP_BMI_REL &&  p.n)
            mop_next    = MOP_REL_TAKEN;
        if (cop == OP_BVC_REL && !p.v)
            mop_next    = MOP_REL_TAKEN;
        if (cop == OP_BVS_REL &&  p.v)
            mop_next    = MOP_REL_TAKEN;
    end

    if (mop == MOP_REL_TAKEN) begin
        // Read EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        // ALU = ADD + PCL
        alu_mode        = ALU_ADD_PCL;
        // PCL = ALU
        pcl_load_alu    = 1;
        mop_next        = alu_p_pcl_ovf ? MOP_REL_H_FIX : MOP_PC_FETCH;
    end

    if (mop == MOP_REL_H_FIX) begin
        // Read EXT.PC
        ext_bus         = EXT_PC;
        ext_read        = 1;
        // PCH = c ? PCH + 1 : PCH - 1
        pch_inc         = add[8];
        pch_dec         = ~add[8];
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_TXFR) begin
        // REG.A = X
        if (cop == OP_TXA) begin
            a_load_x    = 1;
            p_value.z   = x == 0;
            p_value.n   = x[7];
        end
        // REG.A = Y
        if (cop == OP_TYA) begin
            a_load_y    = 1;
            p_value.z   = y == 0;
            p_value.n   = y[7];
        end
        // REG.X = A
        if (cop == OP_TAX) begin
            x_load_a    = 1;
            p_value.z   = a == 0;
            p_value.n   = a[7];
        end
        // REG.X = S
        if (cop == OP_TSX) begin
            x_load_s    = 1;
            p_value.z   = s == 0;
            p_value.n   = s[7];
        end
        // REG.Y = A
        if (cop == OP_TAY) begin
            y_load_a    = 1;
            p_value.z   = a == 0;
            p_value.n   = a[7];
        end
        // REG.S = X
        if (cop == OP_TXS) begin
            s_load_x    = 1;
            p_value.z   = x == 0;
            p_value.n   = x[7];
        end
        p_update.z      = 1;
        p_update.n      = 1;
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_ALU) begin
        p_value         = alu_p_value;
        p_update.z      = 1;
        p_update.n      = 1;
        if (cop == OP_INX || cop == OP_DEX) begin
            alu_mode    = cop == OP_INX ? ALU_X_INC : ALU_X_DEC;
            x_load_alu  = 1;
        end
        if (cop == OP_INY || cop == OP_DEY) begin
            alu_mode    = cop == OP_INY ? ALU_Y_INC : ALU_Y_DEC;
            y_load_alu  = 1;
        end
        if (cop == OP_ASL_ACC) begin
            alu_mode    = ALU_ADD_SL;
            a_load_alu  = 1;
            p_update.c  = 1;
        end
        if (cop == OP_LSR_ACC) begin
            alu_mode    = ALU_ADD_SR;
            a_load_alu  = 1;
            p_update.c  = 1;
        end
        if (cop == OP_ROL_ACC) begin
            alu_mode    = ALU_ADD_SL_C;
            a_load_alu  = 1;
            p_update.c  = 1;
        end
        if (cop == OP_ROR_ACC) begin
            alu_mode    = ALU_ADD_SR_C;
            a_load_alu  = 1;
            p_update.c  = 1;
        end
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_BIT) begin
        // ALU = EXT.AD & REG.A
        ext_bus         = EXT_AD;
        ext_read        = 1;
        alu_mode        = ALU_A_AND_EXT;
        p_update.z      = 1;
        p_value.z       = alu_p_value.z;
        p_update.v      = 1;
        p_value.v       = READ_DATA_IN[6];
        p_update.n      = 1;
        p_value.n       = READ_DATA_IN[7];
        mop_next        = MOP_PC_FETCH;
    end

    if (mop == MOP_FLAGS) begin
        if (cop == OP_CLC || cop == OP_SEC) begin
            p_update.c  = 1;
            p_value.c   = cop == OP_SEC;
        end
        if (cop == OP_CLD || cop == OP_SED) begin
            p_update.d  = 1;
            p_value.d   = cop == OP_SED;
        end
        if (cop == OP_CLI || cop == OP_SEI) begin
            p_update.i  = 1;
            p_value.i   = cop == OP_SEI;
        end
        if (cop == OP_CLV) begin
            p_update.v  = 1;
            p_value.v   = 0;
        end
        mop_next        = MOP_PC_FETCH;
    end
end


// Debug info
`ifdef SIMULATION
typedef struct packed {
    op_t op;
    u16_t pc;
} debug_t;
debug_t debug;

initial begin
    forever begin
        if (mop == MOP_INT_RESET) begin
            debug.op = OP_BRK;
            debug.pc = 'hfffc;
        end

        if (mop == MOP_PC_FETCH) begin
            @(negedge READ_ENABLE_OUT);
            @(negedge CLK);
            debug.op = op_t'(READ_DATA_IN);
            debug.pc = pc;
        end

        @(negedge CLK_ENABLE_IN);
        @(posedge CLK);
    end
end
`endif


endmodule
