module FIFO_ASYNC #(
    parameter WIDTH = 8, DEPTH = 5    // Depth of 5 allows no stalling
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

typedef struct packed {
    logic Toggle;
    logic [$clog2(DEPTH)-1:0] Ptr;
} ctrl_t;

logic [DEPTH-1:0][WIDTH-1:0] data;
ctrl_t wwptr, wwptrn, wrptr, wrptrp;
ctrl_t rrptr, rrptrn, rwptr, rwptrp;

// Write data
always_ff @(posedge WCLK)
    if (WRITE & ~WFULL)
        data[wwptr.Ptr] <= WDATA;

// Next wwptr
always_comb begin
    wwptrn.Ptr    = wwptr.Ptr + 1;
    wwptrn.Toggle = wwptr.Toggle;
    if (wwptr.Ptr == DEPTH - 1) begin
        wwptrn.Ptr    = 0;
        wwptrn.Toggle = ~wwptr.Toggle;
    end
end

assign WFULL = (wwptr.Ptr == wrptr.Ptr) && (wwptr.Toggle != wrptr.Toggle);

// Write pointer
always_ff @(posedge WCLK, posedge WRESET)
    if (WRESET)
        wwptr <= '{default: 0};
    else if (WRITE & ~WFULL)
        wwptr <= wwptrn;

// Read pointer synchronised to write port
always_ff @(posedge WCLK, posedge WRESET)
    if (WRESET)
        {wrptr, wrptrp} <= '{default: 0};
    else
        {wrptr, wrptrp} <= {wrptrp, rrptr};

// Read data
assign RDATA  = data[rrptr.Ptr];

// Next rrptr
always_comb begin
    rrptrn.Ptr    = rrptr.Ptr + 1;
    rrptrn.Toggle = rrptr.Toggle;
    if (rrptr.Ptr == DEPTH - 1) begin
        rrptrn.Ptr    = 0;
        rrptrn.Toggle = ~rrptr.Toggle;
    end
end

// Read pointer
assign REMPTY = rwptr == rrptr;

always_ff @(posedge RCLK, posedge RRESET)
    if (RRESET)
        rrptr <= '{default: 0};
    else if (READ & ~REMPTY)
        rrptr <= rrptrn;

// Write pointer synchronised to read port
always_ff @(posedge RCLK, posedge RRESET)
    if (RRESET)
        {rwptr, rwptrp} <= '{default: 0};
    else
        {rwptr, rwptrp} <= {rwptrp, wwptr};

endmodule
