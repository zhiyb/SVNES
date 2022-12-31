module SDRAM
#(
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2,
                  tINIT = 14250, tREF = 1114,
    parameter SDRAM_PKG::cas_t   CAS   = SDRAM_PKG::CAS_3,
    parameter SDRAM_PKG::burst_t BURST = SDRAM_PKG::BURST_8
) (
    input wire CLK,
    input wire RESET_IN,

    // Hardware interface
    inout  wire  [15:0] DRAM_DQ,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output logic        DRAM_CLK, DRAM_CKE,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

logic [14:0] mrs;
assign mrs = {5'b0, 1'b0, 2'b0, CAS[2:0], 1'b0, BURST[2:0]};

assign DRAM_CLK = CLK;

SDRAM_PKG::cmd_t cmd_data;
logic cmd_req, cmd_ack;

FIFO_SYNC #(
    .DATA_T     (SDRAM_PKG::cmd_t),
    .DEPTH_LOG2 (2)
) cmd_fifo (
    .CLK        (CLK),
    .RESET_IN   (RESET_IN),

    .IN_DATA    (),
    .IN_REQ     (1'b0),
    .IN_ACK     (),

    .OUT_DATA   (cmd_data),
    .OUT_REQ    (cmd_req),
    .OUT_ACK    (cmd_ack)
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
    .RESET_IN   (RESET),

    .CMD_DATA   (cmd_data),
    .CMD_REQ    (cmd_req),
    .CMD_ACK    (cmd_ack),

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
