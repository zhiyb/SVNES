package AHB_PKG;

typedef logic [31:0] addr_t;
typedef logic [31:0] data_t;

// Burst types
typedef enum logic [2:0] {
    BURST_SINGLE = 3'b000,
    BURST_INCR   = 3'b001,
    BURST_WRAP4  = 3'b010,
    BURST_INCR4  = 3'b011,
    BURST_WRAP8  = 3'b100,
    BURST_INCR8  = 3'b101,
    BURST_WRAP16 = 3'b110,
    BURST_INCR16 = 3'b111
} burst_enum_t;

// Transfer types
typedef enum logic [1:0] {
    TRANS_IDLE   = 2'b00,
    TRANS_BUSY   = 2'b01,
    TRANS_NONSEQ = 2'b10,
    TRANS_SEQ    = 2'b11
} trans_enum_t;

// Transfer size
typedef enum logic [2:0] {
    SIZE_1  = 3'b000,
    SIZE_2  = 3'b001,
    SIZE_4  = 3'b010,
    SIZE_8  = 3'b011
} size_enum_t;

// Response type
typedef enum logic [0:0] {
    RESP_OKAY  = 1'b0,
    RESP_ERROR = 1'b1
} resp_enum_t;

`ifdef SIMULATION
typedef burst_enum_t burst_t;
typedef trans_enum_t trans_t;
typedef size_enum_t size_t;
typedef resp_enum_t resp_t;
`else
typedef logic [2:0] burst_t;
typedef logic [1:0] trans_t;
typedef logic [2:0] size_t;
typedef logic [0:0] resp_t;
`endif

endpackage
