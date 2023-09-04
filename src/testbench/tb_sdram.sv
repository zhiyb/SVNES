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
    @(posedge clk_sys);
    @(posedge clk_sys);
    reset_sys = 0;
end

localparam AHB_PORTS = 4;

AHB_PKG::addr_t  [AHB_PORTS-1:0] HADDR;
AHB_PKG::burst_t [AHB_PORTS-1:0] HBURST;
AHB_PKG::size_t  [AHB_PORTS-1:0] HSIZE;
AHB_PKG::trans_t [AHB_PORTS-1:0] HTRANS;
logic            [AHB_PORTS-1:0] HWRITE;
AHB_PKG::data_t  [AHB_PORTS-1:0] HWDATA;
AHB_PKG::data_t  [AHB_PORTS-1:0] HRDATA;
logic            [AHB_PORTS-1:0] HREADY;
AHB_PKG::resp_t  [AHB_PORTS-1:0] HRESP;

wire  [15:0] DRAM_DQ;
logic [12:0] DRAM_ADDR;
logic [1:0]  DRAM_BA, DRAM_DQM;
wire         DRAM_CLK;
logic        DRAM_CKE;
logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;

SDRAM #(
    .AHB_PORTS  (AHB_PORTS)
) sdram (
    .CLK        (clk_sys),
    .CLK_IO     (clk_sys),
    .RESET_IN   (reset_sys),

    .INIT_DONE_OUT  (),

    // Upstream AHB ports
    .HADDR      (HADDR),
    .HBURST     (HBURST),
    .HSIZE      (HSIZE),
    .HTRANS     (HTRANS),
    .HWRITE     (HWRITE),
    .HWDATA     (HWDATA),
    .HRDATA     (HRDATA),
    .HREADY     (HREADY),
    .HRESP      (HRESP),

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

int test;
        initial begin
            test = 0;

            @(negedge reset_sys);
            test = 1;
            @(posedge clk_sys);
            test = 2;

            forever begin
                @(posedge clk_sys);
                test = 3;
            end
        end

// AHB test requests genreator
typedef struct packed {
    logic [20:0] tag;
    logic [2:0]  index;
    logic [3:0]  ofs;
} cache_addr_t;

generate
    genvar i;
    for (i = 0; i < AHB_PORTS; i++) begin: gen_ahb
        // Address phase
        always_ff @(posedge clk_sys, posedge reset_sys) begin
            if (reset_sys) begin
                HADDR[i]  <= 0;
                HBURST[i] <= AHB_PKG::BURST_SINGLE;
                HSIZE[i]  <= AHB_PKG::SIZE_4;
                HTRANS[i] <= AHB_PKG::TRANS_IDLE;
                HWRITE[i] <= 0;
            end else if (HREADY[i]) begin
                // New AHB transfer
                cache_addr_t addr;
                //addr.tag = unsigned'($random()) % 4;
                addr.tag = $random();
                addr.index = $random();
                addr.ofs = $random();
                addr.ofs[1:0] = 0;
                HADDR[i]  <= addr;
                HTRANS[i] <= AHB_PKG::TRANS_NONSEQ;
                HWRITE[i] <= $random() % 2;
            end
        end

        // Data phase
        always_ff @(posedge clk_sys, posedge reset_sys)
            if (reset_sys)
                HWDATA[i] <= 0;
            else if (HTRANS[i] != AHB_PKG::TRANS_IDLE && HREADY[i])
                HWDATA[i] <= $random();
            else if (HTRANS[i] == AHB_PKG::TRANS_IDLE && HREADY[i])
                HWDATA[i] <= 0;
    end:gen_ahb
endgenerate

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
