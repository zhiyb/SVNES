package AHB_PKG;

// Burst types
typedef enum logic [2:0] {
    BURST_SINGLE = 'b000,
    BURST_INCR   = 'b001,
    BURST_WRAP4  = 'b010,
    BURST_INCR4  = 'b011,
    BURST_WRAP8  = 'b100,
    BURST_INCR8  = 'b101,
    BURST_WRAP16 = 'b110,
    BURST_INCR16 = 'b111
} burst_t;

// Transfer types
typedef enum logic [1:0] {
    TRANS_IDLE   = 'b00,
    TRANS_BUSY   = 'b01,
    TRANS_NONSEQ = 'b10,
    TRANS_SEQ    = 'b11
} trans_t;

endpackage
