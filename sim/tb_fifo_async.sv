`timescale 1 ns / 1 ns

module TB_FIFO_ASYNC;

localparam WIDTH = 8;
localparam DEPTH = 4;

logic               WCLK;
logic 	            WRESET;
logic [WIDTH-1:0]   WDATA;
logic               WRITE;
logic               WFULL;

logic               RCLK;
logic               RRESET;
logic [WIDTH-1:0]   RDATA;
logic               READ;
logic               REMPTY;

logic WReset, RReset;

initial begin
    WReset = 1;
    RReset = 1;
    #1ns
    WReset = 0;
    RReset = 0;
end

initial begin
    WCLK = 1;
    forever #2ns WCLK = ~WCLK;
end

initial begin
    RCLK = 1;
    forever #3ns RCLK = ~RCLK;
end

always_ff @(posedge WCLK, posedge WReset)
    WRESET <= WReset;

always_ff @(posedge RCLK, posedge RReset)
    RRESET <= RReset;

FIFO_ASYNC #(
    .WIDTH  (WIDTH),
    .DEPTH  (DEPTH)
) fifo0 (.*);

always_ff @(posedge WCLK, posedge WReset)
    if (WReset)
        WDATA <= 0;
    else if (WRITE & ~WFULL)
        WDATA <= WDATA + 1;

always_ff @(posedge WCLK)
    if (WDATA == WIDTH'(-1))
        $stop();

assign READ  = ~REMPTY;
assign WRITE = ~WFULL;

endmodule
