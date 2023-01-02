module SDRAM_CACHE #(
    parameter int N_SRC = 4,
    parameter int N_DST = 4,
    parameter SDRAM_PKG::burst_t BURST = SDRAM_PKG::BURST_8
) (
    input wire CLK,
    input wire RESET_IN,

    // Upstream AHB ports
    input  wire             HCLK   [N_SRC-1:0],
    input  wire             HRESET [N_SRC-1:0],
    output logic [31:0]     HADDR  [N_SRC-1:0],
    output AHB_PKG::burst_t HBURST [N_SRC-1:0],
    output AHB_PKG::trans_t HTRANS [N_SRC-1:0],
    output logic            HWRITE [N_SRC-1:0],
    output logic [31:0]     HWDATA [N_SRC-1:0],
    input  logic [31:0]     HRDATA [N_SRC-1:0],
    input  logic            HREADY [N_SRC-1:0],
    input  logic            HRESP  [N_SRC-1:0],

    // Downstream ports
    output logic                    [N_DST-1:0] DST_WRITE_OUT,
    output SDRAM_PKG::dram_access_t [N_DST-1:0] DST_ACS_OUT,
    input  SDRAM_PKG::data_t        [N_DST-1:0] DST_DATA_IN,
    output logic                    [N_DST-1:0] DST_REQ_OUT,
    input  logic                    [N_DST-1:0] DST_ACK_IN
);

localparam LINE_BYTES     = SDRAM_PKG::N_BURSTS[BURST] * $bits(SDRAM_PKG::data_t) / 8;
localparam LINE_ADDR_BITS = $clog2(LINE_BYTES);
localparam TAG_INDEX_BITS = SDRAM_PKG::N_BANKS + 4;
localparam TAG_ADDR_BITS  = $clog2(SDRAM_PKG::MAX_BYTES) - LINE_ADDR_BITS - TAG_INDEX_BITS;

typedef logic [LINE_BYTES-1:0][7:0] line_t;

typedef struct packed {
    logic pending;
    logic [LINE_BYTES-1:0] valid, dirty;
    logic [TAG_ADDR_BITS-1:0] addr;
} tag_t;

endmodule
