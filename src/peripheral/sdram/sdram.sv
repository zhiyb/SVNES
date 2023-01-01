module SDRAM #(
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2, tRRD = 2,
                  tINIT = 14250, tREF = 1114,
    parameter SDRAM_PKG::cas_t   CAS   = SDRAM_PKG::CAS_3,
    parameter SDRAM_PKG::burst_t BURST = SDRAM_PKG::BURST_8
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

logic [14:0] mrs;
assign mrs = {5'b0, 1'b0, 2'b0, CAS[2:0], 1'b0, BURST[2:0]};

SDRAM_PKG::cmd_t arb_cmd_data;
logic arb_cmd_req, arb_cmd_ack;
SDRAM_PKG::data_t arb_read_data;
SDRAM_PKG::tag_t  arb_read_tag;

SDRAM_ARB #(
    .NSRC       (4),
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
) arb (
    .CLK            (CLK),
    .RESET_IN       (RESET_IN),

    .INIT_DONE_OUT  (INIT_DONE_OUT),

    .SRC_WRITE_IN   (),
    .SRC_ACS_IN     (),
    .SRC_DATA_OUT   (),
    .SRC_REQ_IN     (),
    .SRC_ACK_OUT    (),

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
    .DEPTH_LOG2 (2)
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
    .CLK        (CLK),
    .RESET_IN   (RESET_IN),

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
    .RESET_IN   (RESET),

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
