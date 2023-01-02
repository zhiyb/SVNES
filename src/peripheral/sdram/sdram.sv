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
SDRAM_PKG::row_t row;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        row <= 0;
    else
        row <= row + 1;

always_comb begin
    cache_write = '{default: 0};
    cache_acs   = '{default: 0};
    cache_req   = '{default: 0};

    cache_write[0]    = 1;
    cache_req[0]      = 1;
    cache_acs[0].row  = row[12:5];
    cache_acs[0].bank = 0;
    cache_acs[0].data = 'h5a5a5a5a;

    cache_write[1]    = 0;
    cache_req[1]      = 1;
    cache_acs[1].row  = row[12:6];
    cache_acs[1].bank = 1;
    cache_acs[1].data = 'h01234567;

    cache_write[2]    = 1;
    cache_req[2]      = 1;
    cache_acs[2].row  = row[12:7];
    cache_acs[2].bank = 2;
    cache_acs[2].data = 'h34343434;

    cache_write[3]    = 0;
    cache_req[3]      = 1;
    cache_acs[3].row  = row[12:8];
    cache_acs[3].bank = 3;
    cache_acs[3].data = 'h01234567;
end


logic                    [N_CMD_QUEUE-1:0] fifo_write;
SDRAM_PKG::dram_access_t [N_CMD_QUEUE-1:0] fifo_acs;
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
    .SRC_DATA_OUT   (fifo_read_data),
    .SRC_REQ_IN     (fifo_req),
    .SRC_ACK_OUT    (fifo_ack),

    .CMD_DATA_OUT   (arb_cmd_data),
    .CMD_REQ_OUT    (arb_cmd_req),
    .CMD_ACK_IN     (arb_cmd_ack),

    .READ_DATA_IN   (arb_read_data),
    .READ_TAG_IN    (arb_read_tag)
);

SDRAM_PKG::cmd_t io_cmd_data;
logic io_cmd_req, io_cmd_ack;
SDRAM_PKG::data_t io_read_data;
SDRAM_PKG::tag_t  io_read_tag;

FIFO_SYNC #(
    .WIDTH      ($bits(SDRAM_PKG::cmd_t)),
    .DEPTH_LOG2 (1)
) cmd_fifo (
    .CLK        (CLK),
    .RESET_IN   (RESET_IN),

    .WRITE_DATA_IN  (arb_cmd_data),
    .WRITE_REQ_IN   (arb_cmd_req),
    .WRITE_ACK_OUT  (arb_cmd_ack),

    .READ_DATA_OUT  (io_cmd_data),
    .READ_REQ_OUT   (io_cmd_req),
    .READ_ACK_IN    (io_cmd_ack)
);

FIFO_SYNC #(
    .WIDTH      ($bits(SDRAM_PKG::tag_t) + $bits(SDRAM_PKG::data_t)),
    .DEPTH_LOG2 (2)
) read_fifo (
    .CLK            (CLK),
    .RESET_IN       (RESET_IN),

    .WRITE_DATA_IN  ({io_read_tag, io_read_data}),
    .WRITE_REQ_IN   (1'b1),
    .WRITE_ACK_OUT  (),

    .READ_DATA_OUT  ({arb_read_tag, arb_read_data}),
    .READ_REQ_OUT   (),
    .READ_ACK_IN    (1'b1)
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

    .CMD_DATA_IN    (io_cmd_data),
    .CMD_REQ_IN     (io_cmd_req),
    .CMD_ACK_OUT    (io_cmd_ack),

    .READ_DATA_OUT  (io_read_data),
    .READ_TAG_OUT   (io_read_tag),

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
