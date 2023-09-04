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

SIM_SDRAM #(
) sim (
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


/*
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
*/

/*
// Memory write test gen
SDRAM_PKG::addr_t addr [3:0];
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        addr <= '{default: 0};
    else begin
        int i;
        for (i = 0; i < 4; i++)
            if (cache_req[i] & cache_ack[i])
                addr[i] <= addr[i] + 1;
    end

logic [4-1:0][3:0] req_cnt;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        req_cnt <= 0;
    else begin
        int i;
        for (i = 0; i < 4; i++)
            if (req_cnt[i] == 0)
                req_cnt[i] <= BURST + 1;
            else if (cache_ack[i] | ~cache_req[i])
                req_cnt[i] <= req_cnt[i] - 1;
    end

always_comb begin
    cache_write = '{default: 0};
    cache_acs   = '{default: 0};
    cache_req   = '{default: 0};

    cache_write[0]    = addr[0][6];
    cache_req[0]      = req_cnt[0] > 1;
    cache_acs[0].row  = {3{addr[0][12:3]}};
    cache_acs[0].bank = addr[0][8:7] + 0;
    cache_acs[0].data = ~addr[0];

    cache_write[1]    = addr[1][5];
    cache_req[1]      = req_cnt[1] > 1;
    cache_acs[1].row  = {3{addr[1][12:4]}};
    cache_acs[1].bank = addr[1][8:7] + 1;
    cache_acs[1].data = ~addr[1];

    cache_write[2]    = addr[2][4];
    cache_req[2]      = req_cnt[2] > 1;
    cache_acs[2].row  = {3{addr[2][12:5]}};
    cache_acs[2].bank = addr[2][8:7] + 2;
    cache_acs[2].data = ~addr[2];

    cache_write[3]    = addr[3][3];
    cache_req[3]      = req_cnt[3] > 1;
    cache_acs[3].row  = {3{addr[3][12:6]}};
    cache_acs[3].bank = addr[3][8:7] + 3;
    cache_acs[3].data = ~addr[3];
end
*/

endmodule
