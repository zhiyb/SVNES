module FIFO_SYNC #(
    parameter int WIDTH,
    parameter int DEPTH_LOG2
) (
    input  wire              CLK,
    input  wire              RESET_IN,

    // Input write interface
    input  logic [WIDTH-1:0] WRITE_DATA_IN,
    input  logic             WRITE_REQ_IN,
    output logic             WRITE_ACK_OUT,

    // Output read interface
    output logic [WIDTH-1:0] READ_DATA_OUT,
    output logic             READ_REQ_OUT,
    input  logic             READ_ACK_IN
);

logic [WIDTH-1:0] fifo [(2**DEPTH_LOG2)-1:0];
logic [DEPTH_LOG2:0] wptr, rptr;

assign WRITE_ACK_OUT = (DEPTH_LOG2)'(wptr + 1) != (DEPTH_LOG2)'(rptr);

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        wptr <= 0;
    else if (WRITE_REQ_IN & WRITE_ACK_OUT)
        wptr <= wptr + 1;

always_ff @(posedge CLK)
    if (WRITE_REQ_IN & WRITE_ACK_OUT)
        fifo[(DEPTH_LOG2)'(wptr)] <= WRITE_DATA_IN;

assign READ_REQ_OUT = wptr != rptr;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        rptr <= 0;
    else if (READ_REQ_OUT & READ_ACK_IN)
        rptr <= rptr + 1;

assign READ_DATA_OUT = fifo[(DEPTH_LOG2)'(rptr)];

endmodule
