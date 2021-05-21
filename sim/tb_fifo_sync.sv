`timescale 1 ns / 1 ns

module TB_FIFO_SYNC;

localparam WIDTH = 8;
localparam DEPTH = 2;

logic               CLK;
logic 	            RESET;

logic               FULL;
logic               EMPTY;
logic               WRITE;
logic [WIDTH-1:0]   WDATA;
logic               READ;
logic [WIDTH-1:0]   RDATA;

logic WReset, RReset;

initial begin
    RESET = 1;
    #1ns
    RESET = 0;
end

initial begin
    CLK = 1;
    forever #1ns CLK = ~CLK;
end

FIFO_SYNC #(
    .WIDTH  (WIDTH),
    .DEPTH  (DEPTH)
) fifo0 (.*);

always_ff @(posedge CLK, posedge RESET)
    if (RESET)
        WDATA <= 0;
    else if (WRITE & ~FULL)
        WDATA <= WDATA + 1;

always_ff @(posedge CLK)
    if (WDATA == WIDTH'(-1))
        $finish(0);

assign READ  = ~EMPTY;
assign WRITE = ~FULL;

endmodule
