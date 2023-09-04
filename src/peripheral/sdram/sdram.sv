module SDRAM #(
    parameter int AHB_PORTS   = 4,
    parameter int N_CMD_QUEUE = 4,
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

    // Upstream AHB ports
    input  AHB_PKG::addr_t  [AHB_PORTS-1:0] HADDR,
    input  AHB_PKG::burst_t [AHB_PORTS-1:0] HBURST,
    input  AHB_PKG::size_t  [AHB_PORTS-1:0] HSIZE,
    input  AHB_PKG::trans_t [AHB_PORTS-1:0] HTRANS,
    input  logic            [AHB_PORTS-1:0] HWRITE,
    input  AHB_PKG::data_t  [AHB_PORTS-1:0] HWDATA,
    output AHB_PKG::data_t  [AHB_PORTS-1:0] HRDATA,
    output logic            [AHB_PORTS-1:0] HREADY,
    output AHB_PKG::resp_t  [AHB_PORTS-1:0] HRESP,

    // Hardware interface
    inout  wire  [15:0] DRAM_DQ,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output wire         DRAM_CLK,
    output logic        DRAM_CKE,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

logic                    [N_CMD_QUEUE-1:0] cache_write;
SDRAM_PKG::dram_access_t [N_CMD_QUEUE-1:0] cache_acs;
SDRAM_PKG::data_t        [N_CMD_QUEUE-1:0] cache_read_data;
logic                    [N_CMD_QUEUE-1:0] cache_req;
logic                    [N_CMD_QUEUE-1:0] cache_ack;

SDRAM_CACHE #(
    .N_SRC  (AHB_PORTS),
    .N_DST  (N_CMD_QUEUE),
    .BURST  (BURST)
) cache (
    .CLK            (CLK),
    .RESET_IN       (RESET_IN),

    .HADDR          (HADDR),
    .HBURST         (HBURST),
    .HSIZE          (HSIZE),
    .HTRANS         (HTRANS),
    .HWRITE         (HWRITE),
    .HWDATA         (HWDATA),
    .HRDATA         (HRDATA),
    .HREADY         (HREADY),
    .HRESP          (HRESP),

    .DST_WRITE_OUT  (cache_write),
    .DST_ACS_OUT    (cache_acs),
    .DST_DATA_IN    (cache_read_data),
    .DST_REQ_OUT    (cache_req),
    .DST_ACK_IN     (cache_ack)
);

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
