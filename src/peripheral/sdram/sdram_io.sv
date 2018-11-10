module SDRAM_IO
#(
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2,
                  tINIT = 14250, tREF = 1114,
    parameter logic [2:0] CAS = 3
) (
    input logic CLK,
    input logic RESET_IN,

    // Hardware interface
    inout  wire  [15:0] DRAM_DQ,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output logic        DRAM_CLK, DRAM_CKE,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

endmodule
