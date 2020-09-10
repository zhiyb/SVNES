module FIFO_SYNC #(
    parameter WIDTH, DEPTH = 4
) (
    input  wire                 CLK,
    input  logic                RESET,

    output logic                FULL,
    output logic                EMPTY,
    input  logic                WRITE,
    input  logic [WIDTH-1:0]    WDATA,
    input  logic                READ,
    output logic [WIDTH-1:0]    RDATA
);

typedef logic [$clog2(DEPTH)-1:0] ptr_t;

logic [DEPTH-1:0][WIDTH-1:0] data;
ptr_t wptr, wptrn;
ptr_t rptr;

// Write data
always_ff @(posedge CLK)
    if (WRITE)
        data[wptr] <= WDATA;

// Next write pointer
assign wptrn = wptr == DEPTH - 1 ? 0 : wptr + 1;

// Full or empty when pointers equal
logic full;

always_ff @(posedge CLK, posedge RESET)
    if (RESET)
        full <= 0;
    else
        full <= WRITE & ~READ & (wptrn == rptr);

assign FULL = full;

// Write pointer
always_ff @(posedge CLK, posedge RESET)
    if (RESET)
        wptr <= 0;
    else if (WRITE & ~FULL)
        wptr <= wptrn;

// Read data
assign RDATA  = data[rptr];

// Read pointer
assign EMPTY = ~full & (wptr == rptr);

always_ff @(posedge CLK, posedge RESET)
    if (RESET)
        rptr <= 0;
    else if (READ & ~EMPTY)
        rptr <= rptr == DEPTH - 1 ? 0 : rptr + 1;

endmodule
