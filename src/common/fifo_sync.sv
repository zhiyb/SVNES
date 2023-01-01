module FIFO_SYNC #(
    parameter int WIDTH,
    parameter int DEPTH_LOG2
) (
    input wire CLK,
    input wire RESET_IN,

    // Input interface
    input  logic [WIDTH-1:0] IN_DATA,
    input  logic             IN_REQ,
    output logic             IN_ACK,

    // Output interface
    output logic [WIDTH-1:0] OUT_DATA,
    output logic             OUT_REQ,
    input  logic             OUT_ACK
);

typedef logic [DEPTH_LOG2-1:0] ptr_t;

logic [WIDTH-1:0] fifo [(2**DEPTH_LOG2)-1:0];
ptr_t wptr, rptr;

assign IN_ACK = ptr_t'(wptr + 1) != rptr;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        wptr <= 0;
    else if (IN_REQ & IN_ACK)
        wptr <= wptr + 1;

always_ff @(posedge CLK)
    if (IN_REQ & IN_ACK)
        fifo[wptr] <= IN_DATA;

assign OUT_REQ = wptr != rptr;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        rptr <= 0;
    else if (OUT_REQ & OUT_ACK)
        rptr <= rptr + 1;

assign OUT_DATA = fifo[rptr];

endmodule
