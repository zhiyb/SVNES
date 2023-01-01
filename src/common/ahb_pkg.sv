package AHB_PKG;

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
} burst_t;

// Transfer types
typedef enum logic [1:0] {
    TRANS_IDLE   = 2'b00,
    TRANS_BUSY   = 2'b01,
    TRANS_NONSEQ = 2'b10,
    TRANS_SEQ    = 2'b11
} trans_t;

endpackage
