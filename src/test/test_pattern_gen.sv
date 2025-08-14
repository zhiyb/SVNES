module TEST_PATTERN_GEN #(
    // DMA base address
    parameter logic [31:0] BASE_ADDR = 0,
    parameter int AHB_BURSTS = 4
) (
    // AHB memory DMA master
    input  wire             HCLK,
    input  wire             HRESET,
    output AHB_PKG::addr_t  HADDR,
    output AHB_PKG::burst_t HBURST,
    output AHB_PKG::size_t  HSIZE,
    output AHB_PKG::trans_t HTRANS,
    output logic            HWRITE,
    output AHB_PKG::data_t  HWDATA,
    input  AHB_PKG::data_t  HRDATA,
    input  logic            HREADY,
    input  AHB_PKG::resp_t  HRESP,

    // Controls
    input  logic            START_IN
);

assign HBURST = AHB_BURSTS == 4 ? AHB_PKG::BURST_INCR4 :
                                  AHB_PKG::BURST_SINGLE;
assign HSIZE  = AHB_PKG::SIZE_4;
// Only write transfers
assign HWRITE = 1;


always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        HADDR <= 0;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && START_IN)
        HADDR <= BASE_ADDR + (5 * 800 + 8) * 2;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE)
        HADDR <= HADDR + 4;

logic data_phase;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        data_phase <= 0;
    else if (HREADY)
        data_phase <= HTRANS != AHB_PKG::TRANS_IDLE;

// assign HWDATA = 'h0000ffff;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        HWDATA <= 'h0000ffff;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && START_IN)
        HWDATA <= ~HWDATA;

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        HTRANS <= AHB_PKG::TRANS_IDLE;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && START_IN)
        HTRANS <= AHB_PKG::TRANS_NONSEQ;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE && &HADDR[2 +: $clog2(AHB_BURSTS)])
        HTRANS <= AHB_PKG::TRANS_IDLE;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE)
        HTRANS <= AHB_PKG::TRANS_SEQ;


endmodule
