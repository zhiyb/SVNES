module TB_SDRAM;

initial
    #2ms $finish(0);

// 143MHz memory clock
logic clk_sys;

initial
begin
    clk_sys = 0;
    forever
        #(0.5/143.0 * 1us) clk_sys = ~clk_sys;
end

logic reset_sys;

initial
begin
    reset_sys = 0;
    reset_sys = 1;
    @(posedge clk_sys);
    reset_sys = 0;
end

wire  [15:0] DRAM_DQ;
logic [12:0] DRAM_ADDR;
logic [1:0]  DRAM_BA, DRAM_DQM;
wire         DRAM_CLK;
logic        DRAM_CKE;
logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;

SDRAM #() sdram (
    .CLK        (clk_sys),
    .CLK_IO     (clk_sys),
    .RESET_IN   (reset_sys),

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

// SDRAM fake read data generator
localparam N_CAS    = 3;
localparam N_BURSTS = 8;

logic read_cmd;
assign read_cmd = {DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N} == 3'b101;

logic [3:0] burst_cnt;
always_ff @(posedge DRAM_CLK, posedge reset_sys)
    if (reset_sys)
        burst_cnt <= 0;
    else if (read_cmd)
        burst_cnt <= N_BURSTS;
    else if (burst_cnt != 0)
        burst_cnt <= burst_cnt - 1;

localparam READ_LATENCY = N_CAS - 1;
logic [READ_LATENCY-1:0] read_pipe;
always_ff @(posedge DRAM_CLK)
    read_pipe <= {read_pipe, burst_cnt != 0};

logic read_valid;
assign read_valid = read_pipe[READ_LATENCY-1];

logic [15:0] read_data;
always_ff @(posedge DRAM_CLK, posedge reset_sys)
    if (reset_sys)
        read_data <= 0;
    else if (read_valid)
        read_data <= read_data + 1;

assign DRAM_DQ = read_valid ? read_data : 'z;

endmodule
