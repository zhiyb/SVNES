package SDRAM_PKG;

typedef enum int {
    BURST_1 = 0,
    BURST_2 = 1,
    BURST_4 = 2,
    BURST_8 = 3
} burst_t;
localparam int N_BURSTS[4] = '{1, 2, 4, 8};

typedef enum int {
    CAS_2 = 2,
    CAS_3 = 3
} cas_t;
localparam int N_CAS[4] = '{0, 1, 2, 3};

typedef enum logic [2:0] {
    OP_NOP   = 3'h0,
    OP_REF   = 3'h1,
    OP_PRE   = 3'h2,
    OP_ACT   = 3'h3,
    OP_WRITE = 3'h4,
    OP_READ  = 3'h5,
    OP_MRS   = 3'h7
} op_t;

localparam N_BANKS     = 4;
localparam N_BAN_BITS  = $clog2(N_BANKS);
localparam N_ROW_BITS  = 13;
localparam N_COL_BITS  = 10;
localparam N_ADDR_BITS = 13;    // Maximum of ROW and COL
localparam N_DATA_BITS = 16;
localparam N_TAG_BITS  = 3;     // Concurrent access

localparam PALL_BIT    = 10;    // Precharge all banks bit

typedef logic [N_BAN_BITS-1:0]  ba_t;
typedef logic [N_ROW_BITS-1:0]  row_t;
typedef logic [N_COL_BITS-1:0]  col_t;
typedef logic [N_ADDR_BITS-1:0] addr_t;
typedef logic [N_DATA_BITS-1:0] data_t;
typedef logic [N_TAG_BITS-1:0]  tag_t;

typedef struct packed {
    ba_t   bank;
    row_t  row;
    col_t  col;
    data_t data;
} dram_access_t;

typedef struct packed {
    op_t   op;
    ba_t   bank;
    // addr[PALL_BIT] also acts as 'all bank' select for precharge
    // addr also acts as row number for active
    // addr also acts as col number for read/write access
    addr_t addr;
    // data also acts as mode register value
    // data may be used during precharge/active for on-going write burst
    // data also used to transfer tag value for read burst
    data_t data;
} cmd_t;

function logic [3:0] max(logic [3:0] a, logic [3:0] b);
    max = a > b ? a : b;
endfunction

endpackage
