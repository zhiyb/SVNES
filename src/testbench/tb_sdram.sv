module TB_SDRAM;

initial
    #1ms $finish(0);

// 143*2 = 286MHz system clock
logic CLK;

initial
begin
    CLK = 1;
    forever
        #(0.5/286 * 1us) CLK = ~CLK;
end

logic RESET;

initial
begin
    RESET = 0;
    @(posedge CLK);
    RESET = 1;
    @(posedge CLK);
    RESET = 0;
end

wire  [15:0] DRAM_DQ;
logic [12:0] DRAM_ADDR;
logic [1:0]  DRAM_BA, DRAM_DQM;
logic        DRAM_CLK, DRAM_CKE;
logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;

SDRAM_IO
#() io
(
    .CLK        (CLK),
    .RESET_IN   (RESET),

    // Hardware interface
    .DRAM_DQ    (DRAM_DQ),
    .DRAM_ADDR  (DRAM_ADDR),
    .DRAM_BA    (DRAM_BA),
    .DRAM_DQM   (DRAM_DQM),
    .DRAM_CLK   (DRAM_CLK),
    .DRAM_CKE   (DRAM_CKE),
    .DRAM_CS_N  (DRAM_CS_N),
    .DRAM_RAS_N (DRAM_RAS_N),
    .DRAM_CAS_N (DRAM_CAS_N),
    .DRAM_WE_N  (DRAM_WE_N)
);

endmodule
