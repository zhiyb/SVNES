module SDRAM #(
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2, tRRD = 2,
                  tINIT = 14250, tREF = 1114,
                  CAS = 3, BURST = 8
) (
    input wire CLK,
    input wire CLK_IO,
    input wire RESET_IN,

    output logic INIT_DONE_OUT,

    // Hardware interface
    inout  wire  [15:0] DRAM_DQ,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output wire         DRAM_CLK,
    output logic        DRAM_CKE,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

localparam N_CMD_QUEUE  = 4;

logic                    [N_CMD_QUEUE-1:0] cache_write;
SDRAM_PKG::dram_access_t [N_CMD_QUEUE-1:0] cache_acs;
SDRAM_PKG::data_t        [N_CMD_QUEUE-1:0] cache_read_data;
logic                    [N_CMD_QUEUE-1:0] cache_req;
logic                    [N_CMD_QUEUE-1:0] cache_ack;


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


logic                    [N_CMD_QUEUE-1:0] fifo_write;
SDRAM_PKG::dram_access_t [N_CMD_QUEUE-1:0] fifo_acs;
logic                    [N_CMD_QUEUE-1:0] fifo_rchg;
SDRAM_PKG::data_t        [N_CMD_QUEUE-1:0] fifo_read_data;
logic                    [N_CMD_QUEUE-1:0] fifo_req;
logic                    [N_CMD_QUEUE-1:0] fifo_ack;

SDRAM_FIFO #(
    .N_PORTS    (N_CMD_QUEUE)
) cmd_arb_fifo (
    .CLK            (CLK),
    .RESET_IN       (RESET_IN),

    .SRC_WRITE_IN   (cache_write),
    .SRC_ACS_IN     (cache_acs),
    .SRC_DATA_OUT   (cache_read_data),
    .SRC_REQ_IN     (cache_req),
    .SRC_ACK_OUT    (cache_ack),

    .DST_WRITE_OUT  (fifo_write),
    .DST_ACS_OUT    (fifo_acs),
    .DST_RCHG_OUT   (fifo_rchg),
    .DST_DATA_IN    (fifo_read_data),
    .DST_REQ_OUT    (fifo_req),
    .DST_ACK_IN     (fifo_ack)
);

SDRAM_PKG::cmd_t arb_cmd_data;
logic arb_cmd_req, arb_cmd_ack;
SDRAM_PKG::data_t arb_read_data;
SDRAM_PKG::tag_t  arb_read_tag;

SDRAM_ARB #(
    .N_SRC      (N_CMD_QUEUE),
    .tRC        (tRC),
    .tRAS       (tRAS),
    .tRP        (tRP),
    .tRCD       (tRCD),
    .tMRD       (tMRD),
    .tDPL       (tDPL),
    .tQMD       (tQMD),
    .tRRD       (tRRD),
    .tINIT      (tINIT),
    .tREF       (tREF),
    .CAS        (CAS),
    .BURST      (BURST)
) cmd_arb (
    .CLK            (CLK),
    .RESET_IN       (RESET_IN),

    .INIT_DONE_OUT  (INIT_DONE_OUT),

    .SRC_WRITE_IN   (fifo_write),
    .SRC_ACS_IN     (fifo_acs),
    .SRC_RCHG_IN    (fifo_rchg),
    .SRC_DATA_OUT   (fifo_read_data),
    .SRC_REQ_IN     (fifo_req),
    .SRC_ACK_OUT    (fifo_ack),

    .CMD_OUT        (arb_cmd_data),
    .READ_DATA_IN   (arb_read_data),
    .READ_TAG_IN    (arb_read_tag)
);

SDRAM_IO #(
    .tRC        (tRC),
    .tRAS       (tRAS),
    .tRP        (tRP),
    .tRCD       (tRCD),
    .tMRD       (tMRD),
    .tDPL       (tDPL),
    .tQMD       (tQMD),
    .tINIT      (tINIT),
    .tREF       (tREF),
    .CAS        (CAS),
    .BURST      (BURST)
) io (
    .CLK        (CLK),
    .CLK_IO     (CLK_IO),
    .RESET_IN   (RESET_IN),

    .CMD_IN         (arb_cmd_data),
    .READ_DATA_OUT  (arb_read_data),
    .READ_TAG_OUT   (arb_read_tag),

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
