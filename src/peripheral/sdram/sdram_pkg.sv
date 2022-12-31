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

typedef struct {
    op_t op;
    logic [1:0]  bank;
    union {
        struct {
            logic all;
        } pre;
        struct {
            logic [12:0] row;
        } act;
        struct {
            logic [15:0] data;
            logic [9:0]  col;
        } write;
        struct {
            logic [9:0]  col;
        } read;
        logic [14:0] mrs;
    } data;
} cmd_t;

endpackage
