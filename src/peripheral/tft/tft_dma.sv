module TFT_DMA #(
    parameter int WIDTH,
    parameter int HEIGHT,
    parameter int BPP,
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

    // Data output
    output logic [31:0]     DATA_OUT,
    output logic            REQ_OUT,
    input  logic            ACK_IN,

    // DMA restarts after VSYNC
    input  logic            VSYNC_IN
);

// DMA start at first VSYNC
logic z1_vsync;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        z1_vsync <= 0;
    else if (VSYNC_IN)
        z1_vsync <= 1;

logic dma_enable, dma_start;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET) begin
        dma_start <= 0;
        dma_enable <= 0;
    end else begin
        dma_start <= VSYNC_IN && ~z1_vsync;
        if (dma_start)
            dma_enable <= 1;
    end

// Address phase

localparam DATA_BYTES = HEIGHT * WIDTH * BPP / 8;

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET) begin
        HADDR <= 0;
    end else if (dma_start) begin
        HADDR <= BASE_ADDR;
    end else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE && HTRANS != AHB_PKG::TRANS_BUSY) begin
        HADDR <= HADDR == BASE_ADDR + DATA_BYTES - 4 ? BASE_ADDR : HADDR + 4;
    end

logic fifo_stall;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET) begin
        HTRANS <= AHB_PKG::TRANS_IDLE;
    end else if (HREADY && dma_enable) begin
        if (HTRANS == AHB_PKG::TRANS_IDLE || &HADDR[2 +: $clog2(AHB_BURSTS)])   // Idle or last beat in burst
            HTRANS <= fifo_stall ? AHB_PKG::TRANS_IDLE :    // Wait for downstream
                                   AHB_PKG::TRANS_NONSEQ;   // Start new transfer
        else if (HTRANS != AHB_PKG::TRANS_IDLE)             // Burst in progress
            HTRANS <= fifo_stall ? AHB_PKG::TRANS_BUSY :    // Wait for downstream
                                   AHB_PKG::TRANS_SEQ;      // Continue burst
    end

assign HBURST = AHB_BURSTS == 4 ? AHB_PKG::BURST_INCR4 :
                                  AHB_PKG::BURST_SINGLE;
assign HSIZE  = AHB_PKG::SIZE_4;
// Only read transfers
assign HWRITE = 0;

// Data phase

AHB_PKG::trans_t z1_trans;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        z1_trans <= AHB_PKG::TRANS_IDLE;
    else if (HREADY)
        z1_trans <= HTRANS;

logic data_valid;
assign data_valid = HREADY && z1_trans != AHB_PKG::TRANS_IDLE && z1_trans != AHB_PKG::TRANS_BUSY;

// FIFO needed to handle the slack
(* ramstyle = "no_rw_check" *) logic [31:0] fifo [4];
logic [2:0] wcnt, rcnt;

always_ff @(posedge HCLK)
    if (data_valid)
        fifo[wcnt[1:0]] <= HRDATA;

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        wcnt <= 0;
    else if (data_valid)
        wcnt <= wcnt + 1;

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        rcnt <= 0;
    else if (REQ_OUT & ACK_IN)
        rcnt <= rcnt + 1;

assign REQ_OUT = wcnt != rcnt;
assign DATA_OUT = fifo[rcnt[1:0]];

// Leave at least 2 spaces before stall: stall -> busy -> data
assign fifo_stall = 3'(wcnt - rcnt) >= 2;

// Only read transfers
assign HWDATA = 0;

endmodule
