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

// CPU system bus
typedef logic [15:0] addr_t;
typedef logic [7:0]  data_t;
addr_t sys_addr;
data_t sys_data;
logic  sys_read, sys_write;

// External bus
logic ext_read_next, ext_write_next;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        READ_ENABLE_OUT  <= 0;
        WRITE_ENABLE_OUT <= 0;
    end else if (CLK_ENABLE_IN) begin
        READ_ENABLE_OUT  <= ext_read_next;
        WRITE_ENABLE_OUT <= ext_write_next;
    end else begin
        READ_ENABLE_OUT  <= 0;
        WRITE_ENABLE_OUT <= 0;
    end
end

assign ADDR_OUT         = sys_addr;
assign WRITE_DATA_OUT   = sys_data;


// Registers
typedef logic [7:0]  u8_t;
typedef logic [15:0] u16_t;
u8_t a, x, y;


// Status register
u8_t p;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        p <= 0;
    end else if (CLK_ENABLE_IN) begin
    end
end


// Stack pointer
u8_t s_reg;
int sp_dec;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        s_reg <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (sp_dec)
            s_reg <= s_reg - 1;
    end
end

u16_t s;
assign s = {7'b0, 1'b1, s_reg};


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


// Program counter
u16_t pc;
logic pch_update, pcl_update;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        pc <= 0;
    end else if (CLK_ENABLE_IN) begin
        if (pch_update)
            pc[15:8] <= sys_data;
        else if (pcl_update)
            pc[7:0] <= sys_data;
    end
end


// Microcode processor
typedef enum {
    MOP_INT_RESET,
    MOP_INT_PCH_PUSH,
    MOP_INT_PCL_PUSH,
    MOP_INT_P_PUSH,
    MOP_INT_PCL_FETCH,
    MOP_INT_PCH_FETCH,
    MOP_PC_FETCH
} mop_t;
mop_t mop, mop_next;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        mop <= MOP_INT_RESET;
    end else if (CLK_ENABLE_IN) begin
        mop <= mop_next;
    end
end

always_comb begin
    sys_addr = 0;
    sys_data = 0;
    ext_read_next = 0;
    ext_write_next = 0;
    sp_dec = 0;
    pch_update = 0;
    pcl_update = 0;
    int_reset_clear = 0;
    int_nmi_clear = 0;
    mop_next = mop;

    if (mop == MOP_INT_RESET) begin
        mop_next = MOP_INT_PCH_PUSH;
        ext_write_next = 1;
    end

    if (mop == MOP_INT_PCH_PUSH) begin
        sys_addr  = s;
        sys_data  = pc[15:8];
        sp_dec    = 1;
        mop_next   = MOP_INT_PCL_PUSH;
        ext_write_next = 1;
    end

    if (mop == MOP_INT_PCL_PUSH) begin
        sys_addr  = s;
        sys_data  = pc[7:0];
        sp_dec    = 1;
        mop_next   = MOP_INT_P_PUSH;
        ext_write_next = 1;
    end

    if (mop == MOP_INT_P_PUSH) begin
        sys_addr  = s;
        sys_data  = p;
        sp_dec    = 1;
        mop_next   = MOP_INT_PCL_FETCH;
        ext_read_next = 1;
    end

    if (mop == MOP_INT_PCL_FETCH) begin
        if (int_reset)
            sys_addr    = 'hfffc;
        sys_data = READ_DATA_IN;
        pcl_update = 1;
        mop_next         = MOP_INT_PCH_FETCH;
        ext_read_next = 1;
    end

    if (mop == MOP_INT_PCH_FETCH) begin
        if (int_reset)
            sys_addr    = 'hfffd;
        sys_data = READ_DATA_IN;
        int_reset_clear = 1;
        int_nmi_clear   = 1;
        sys_data        = READ_DATA_IN;
        pch_update = 1;
        mop_next         = MOP_PC_FETCH;
        ext_read_next = 1;
    end

    if (mop == MOP_PC_FETCH) begin
        sys_addr = pc;
        sys_data = READ_DATA_IN;
        mop_next  = MOP_PC_FETCH;
    end
end


// Debug info
`ifdef SIMULATION
typedef enum logic [7:0] {
    OP_ADC_IMM   = 'h69,
    OP_ADC_ZP    = 'h65,
    OP_ADC_ZP_X  = 'h75,
    OP_ADC_ABS   = 'h6D,
    OP_ADC_ABS_X = 'h70,
    OP_ADC_ABS_Y = 'h79,
    OP_ADC_IND_X = 'h61,
    OP_ADC_IND_Y = 'h71,
    OP_LDA_IMM   = 'hA9,
    OP_LDA_ZP    = 'hA5,
    OP_LDA_ZP_X  = 'hB5,
    OP_LDA_ABS   = 'hAD,
    OP_LDA_ABS_X = 'hBD,
    OP_LDA_ABS_Y = 'hB9,
    OP_LDA_IND_X = 'hA1,
    OP_LDA_IND_Y = 'hB1,

    OP_BRK = 'h00
} op_t;

typedef struct packed {
    op_t op;
    u16_t pc;
    u16_t pc_fetch;
    u16_t pc_update;
} debug_t;
debug_t debug;

initial begin
    forever begin
        if (mop == MOP_INT_RESET) begin
            debug.op = OP_BRK;
            debug.pc = pc;
        end

        if (mop == MOP_INT_PCL_FETCH) begin
            debug.pc_fetch = sys_addr;
            @(posedge CLK_ENABLE_IN);
            debug.pc_update[7:0] = sys_data;
        end

        if (mop == MOP_INT_PCH_FETCH) begin
            @(posedge CLK_ENABLE_IN);
            debug.pc_update[15:8] = sys_data;
        end

        if (mop == MOP_PC_FETCH) begin
            @(posedge CLK_ENABLE_IN);
            debug.pc = pc;
            debug.op = sys_data;
        end

        @(negedge CLK_ENABLE_IN);
        @(posedge CLK);
    end
end
`endif


endmodule
