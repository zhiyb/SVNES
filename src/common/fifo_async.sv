module FIFO_ASYNC #(
    parameter type DATA_T
) (
    // Input write interface
    input  wire   WRITE_CLK,
    input  wire   WRITE_RESET_IN,
    input  DATA_T WRITE_DATA_IN,
    input  logic  WRITE_REQ_IN,
    output logic  WRITE_ACK_OUT,

    // Output read interface
    input  wire   READ_CLK,
    input  wire   READ_RESET_IN,
    output DATA_T READ_DATA_OUT,
    output logic  READ_REQ_OUT,
    input  logic  READ_ACK_IN
);

// 16-depth gray counter
typedef logic [3:0] cnt_t;
localparam cnt_t bin2gray16 [15:0] = '{
    'b1000, 'b1001, 'b1011, 'b1010, 'b1110, 'b1111, 'b1101, 'b1100,
    'b0100, 'b0101, 'b0111, 'b0110, 'b0010, 'b0011, 'b0001, 'b0000
};
localparam cnt_t gray2bin16 [15:0] = '{
    10, 11,  9,  8, 13, 12, 14, 15,
     5,  4,  6,  7,  2,  3,  1,  0
};

DATA_T fifo [15:0];
cnt_t wwcnt, wrcnt;
cnt_t rwcnt, rrcnt;


// Write port

cnt_t wrcnt_prev;
assign wrcnt_prev = bin2gray16[4'(gray2bin16[wrcnt] - 1)];

cnt_t wwcnt_next;
assign wwcnt_next = bin2gray16[4'(gray2bin16[wwcnt] + 1)];

cnt_t wrrcnt;
always_ff @(posedge WRITE_CLK, posedge WRITE_RESET_IN)
    if (WRITE_RESET_IN)
        {wrcnt, wrrcnt} <= 0;
    else
        {wrcnt, wrrcnt} <= {wrrcnt, rrcnt};

always_ff @(posedge WRITE_CLK, posedge WRITE_RESET_IN)
    if (WRITE_RESET_IN)
        wwcnt <= 0;
    else if (WRITE_REQ_IN & WRITE_ACK_OUT)
        wwcnt <= wwcnt_next;

always_comb begin
    WRITE_ACK_OUT = 1;
    if (wwcnt_next == wrcnt)
        WRITE_ACK_OUT = 0;
    if (wwcnt_next == wrcnt_prev)
        WRITE_ACK_OUT = 0;
end

always_ff @(posedge WRITE_CLK)
    if (WRITE_REQ_IN & WRITE_ACK_OUT)
        fifo[wwcnt] <= WRITE_DATA_IN;


// Read port

cnt_t rrcnt_next;
assign rrcnt_next = bin2gray16[4'(gray2bin16[rrcnt] + 1)];

cnt_t rwwcnt;
always_ff @(posedge READ_CLK, posedge READ_RESET_IN)
    if (READ_RESET_IN)
        {rwcnt, rwwcnt} <= 0;
    else
        {rwcnt, rwwcnt} <= {rwwcnt, wwcnt};

always_ff @(posedge READ_CLK, posedge READ_RESET_IN)
    if (READ_RESET_IN)
        rrcnt <= 0;
    else if (READ_REQ_OUT & READ_ACK_IN)
        rrcnt <= rrcnt_next;

always_comb begin
    READ_REQ_OUT = 1;
    if (rrcnt == rwcnt)
        READ_REQ_OUT = 0;
    if (rrcnt_next == rwcnt)
        READ_REQ_OUT = 0;
end

assign READ_DATA_OUT = fifo[rrcnt];

endmodule
