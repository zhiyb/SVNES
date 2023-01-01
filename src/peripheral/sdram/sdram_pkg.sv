package SDRAM_PKG;

typedef enum int {
    BURST_1 = 0,
    BURST_2 = 1,
    BURST_4 = 2,
    BURST_8 = 3
} burst_t;

typedef enum int {
    CAS_2 = 2,
    CAS_3 = 3
} cas_t;

typedef enum logic [2:0] {
    OP_NOP   = 0,
    OP_REF   = 1,
    OP_PRE   = 2,
    OP_ACT   = 3,
    OP_WRITE = 4,
    OP_READ  = 5,
    OP_MRES  = 7
} op_t;

typedef struct packed {
    op_t op;
    logic [1:0]  bank;
    union packed {
        struct packed {
            logic [24:0] _resv;
            logic all;
        } pre;
        struct packed {
            logic [12:0] _resv;
            logic [12:0] row;
        } act;
        struct packed {
            logic [15:0] data;
            logic [9:0]  col;
        } write;
        struct packed {
            logic [15:0] _resv;
            logic [9:0]  col;
        } read;
        struct packed {
            logic [10:0] _resv;
            logic [14:0] val;
        } mrs;
    } data;
} cmd_t;

endpackage
