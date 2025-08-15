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

(* ramstyle = "no_rw_check" *) logic [WIDTH-1:0] fifo [(2**DEPTH_LOG2)-1:0];
logic [DEPTH_LOG2:0] wptr, rptr;

assign WRITE_ACK_OUT = wptr != (rptr ^ {1'b1, {DEPTH_LOG2{1'b0}}});

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        wptr <= 0;
    else if (WRITE_REQ_IN & WRITE_ACK_OUT)
        wptr <= wptr + 1;

always_ff @(posedge CLK)
    if (WRITE_REQ_IN & WRITE_ACK_OUT)
        fifo[(DEPTH_LOG2)'(wptr)] <= WRITE_DATA_IN;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        rptr <= 0;
        READ_REQ_OUT <= 0;
        READ_DATA_OUT <= 0;
    end else if (wptr != rptr && (!READ_REQ_OUT || READ_ACK_IN)) begin
        // New data available and ready to read
        rptr <= rptr + 1;
        READ_REQ_OUT <= 1;
        READ_DATA_OUT <= fifo[(DEPTH_LOG2)'(rptr)];
    end else if (READ_ACK_IN) begin
        READ_REQ_OUT <= 0;
    end
end

`ifdef SIMULATION
logic [DEPTH_LOG2:0] fifo_level;
assign fifo_level = wptr - rptr;
`endif

endmodule
