module TFT_DMA #(
    // DMA base address
    parameter logic [31:0] BASE_ADDR = 0,
    // DMA buffer length
    parameter logic [31:0] LENGTH = 0
) (
    // AHB memory DMA master
    input  wire             HCLK,
    input  wire             HRESET,
    output logic [31:0]     HADDR,
    output AHB_PKG::burst_t HBURST,
    output AHB_PKG::trans_t HTRANS,
    output logic            HWRITE,
    output logic [31:0]     HWDATA,
    input  logic [31:0]     HRDATA,
    input  logic            HREADY,
    input  logic            HRESP,

    // Data output
    output logic [31:0]     DATA_OUT,
    output logic            REQ_OUT,
    input  logic            ACK_IN,

    // DMA restarts after VSYNC
    input  logic            VSYNC_IN
);

// DMA restart after VSYNC falling edge
logic z1_vsync;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        z1_vsync <= 0;
    else
        z1_vsync <= VSYNC_IN;

logic dma_enable;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        dma_enable <= 0;
    else if (VSYNC_IN)
        dma_enable <= 0;
    else if (z1_vsync)
        dma_enable <= 1;

// Address phase

logic fifo_stall;

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET) begin
        HADDR <= BASE_ADDR;
    end else if (HTRANS == AHB_PKG::TRANS_BUSY) begin
        // Address should not change during BUSY
    end else if (HREADY) begin
        if (~dma_enable && HTRANS == AHB_PKG::TRANS_IDLE)
            HADDR <= BASE_ADDR;     // Transfer terminated, restart
        else if (HTRANS != AHB_PKG::TRANS_IDLE)
            HADDR <= HADDR + 4;     // Continue burst
    end

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET) begin
        HTRANS <= AHB_PKG::TRANS_IDLE;
    end else if (HTRANS == AHB_PKG::TRANS_BUSY) begin
        // It is allowed to terminate a BUSY transfer before READY
        HTRANS <= fifo_stall ? AHB_PKG::TRANS_BUSY : AHB_PKG::TRANS_SEQ;
    end else if (HREADY) begin
        if (HTRANS == AHB_PKG::TRANS_IDLE || &HADDR[2 +: 4])    // Idle or last beat in burst
            HTRANS <= ~dma_enable ? AHB_PKG::TRANS_IDLE :       // Wait for enable
                      fifo_stall  ? AHB_PKG::TRANS_IDLE :       // Wait for downstream
                                    AHB_PKG::TRANS_NONSEQ;      // Start new transfer
        else if (HTRANS != AHB_PKG::TRANS_IDLE)                 // Burst in progress
            HTRANS <= fifo_stall  ? AHB_PKG::TRANS_BUSY :       // Wait for downstream
                                    AHB_PKG::TRANS_SEQ;         // Continue burst
    end

// Only burst 16 transfers
assign HBURST = AHB_PKG::BURST_INCR16;
// Only read transfers
assign HWRITE = 0;

// Data phase

AHB_PKG::trans_t z1_trans;
always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        z1_trans <= AHB_PKG::TRANS_IDLE;
    else
        z1_trans <= HTRANS;

logic data_valid;
assign data_valid = HREADY && z1_trans != AHB_PKG::TRANS_IDLE && z1_trans != AHB_PKG::TRANS_BUSY;

// FIFO needed to handle the slack
logic [31:0] fifo [4];
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
