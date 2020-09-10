module FIFO_ASYNC #(
    parameter WIDTH, DEPTH = 5      // Depth of 5 allows no stalling
) (
    input  wire                 WCLK,
    input  logic                WRESET,
    input  logic [WIDTH-1:0]    WDATA,
    input  logic                WRITE,
    output logic                WFULL,

    input  wire                 RCLK,
    input  logic                RRESET,
    output logic [WIDTH-1:0]    RDATA,
    input  logic                READ,
    output logic                REMPTY
);

typedef logic [$clog2(DEPTH)-1:0] ptr_t;
typedef logic [$clog2(DEPTH):0] cdc_t;

logic [DEPTH-1:0][WIDTH-1:0] data;
cdc_t wwptr, wwptrn, wrptr, wrptrp;
cdc_t rrptr, rrptrn, rwptr, rwptrp;

// Write data
always_ff @(posedge WCLK)
    if (WRITE)
        data[ptr_t'(wwptr)] <= WDATA;

// Next wwptr
always_comb begin
    wwptrn = wwptr + 1;
    if (ptr_t'(wwptr) == DEPTH - 1)
        wwptrn = {~wwptr[$bits(ptr_t)], ptr_t'(0)};
end

assign WFULL = (wwptr ^ wrptr) == {1'b1, ptr_t'(0)};

// Write pointer
always_ff @(posedge WCLK, posedge WRESET)
    if (WRESET)
        wwptr <= 0;
    else if (WRITE & ~WFULL)
        wwptr <= wwptrn;

// Read pointer synchronised to write port
always_ff @(posedge WCLK, posedge WRESET)
    if (WRESET)
        {wrptr, wrptrp} <= 0;
    else
        {wrptr, wrptrp} <= {wrptrp, rrptr};

// Read data
assign RDATA  = data[ptr_t'(rrptr)];

// Next rrptr
always_comb begin
    rrptrn = rrptr + 1;
    if (ptr_t'(rrptr) == DEPTH - 1)
        rrptrn = {~rrptr[$bits(ptr_t)], ptr_t'(0)};
end

// Read pointer
assign REMPTY = rwptr == rrptr;

always_ff @(posedge RCLK, posedge RRESET)
    if (RRESET)
        rrptr <= 0;
    else if (READ & ~REMPTY)
        rrptr <= rrptrn;

// Write pointer synchronised to read port
always_ff @(posedge RCLK, posedge RRESET)
    if (RRESET)
        {rwptr, rwptrp} <= 0;
    else
        {rwptr, rwptrp} <= {rwptrp, wwptr};

endmodule
