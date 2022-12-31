module SDRAM_IO
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

    // Command interface
    input  SDRAM_PKG::cmd_t CMD_DATA,
    input  logic            CMD_REQ,
    output logic            CMD_ACK,

    // Hardware interface
    inout  wire  [15:0] DRAM_DQ,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output logic        DRAM_CLK, DRAM_CKE,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

assign DRAM_CLK = CLK;

endmodule
