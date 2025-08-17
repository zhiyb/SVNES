module TEST_PATTERN_GEN #(
    parameter WIDTH  = 0,
    parameter HEIGHT = 0,
    parameter BPP    = 32,
    // DMA base address
    parameter logic [31:0] BASE_ADDR = 0,
    parameter AHB_BURSTS = 4
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

assign HBURST = AHB_BURSTS == 8 ? AHB_PKG::BURST_INCR8 :
                AHB_BURSTS == 4 ? AHB_PKG::BURST_INCR4 :
                                  AHB_PKG::BURST_SINGLE;
assign HSIZE  = AHB_PKG::SIZE_4;
// Only write transfers
assign HWRITE = 1;

logic start;
always_ff @(posedge HCLK, posedge HRESET) begin
    if (HRESET)
        start <= 0;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && START_IN)
        start <= 1;
    else
        start <= 0;
end

logic [$clog2(WIDTH)-1:0]  x;
logic [$clog2(HEIGHT)-1:0] y;
always_ff @(posedge HCLK, posedge HRESET) begin
    if (HRESET) begin
        x <= 0;
        y <= 0;
    end else if (start) begin
        x <= 0;
        y <= 0;
    end else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE) begin
        if (x >= WIDTH - 1) begin
            x <= 0;
            if (y >= HEIGHT - 1)
                y <= 0;
            else
                y <= y + 1;
        end else begin
            x <= x + 1;
        end
    end
end

always_comb begin
    // HWDATA = y[0] ? 'h00ffffff : 0;
    HWDATA = x[0] ^ y[0] ? 'h00ffffff : 0;
    if (x == 4)
        HWDATA = 'h0066ccff;
    if (y == 4)
        HWDATA = 'h00ff0000;
// `ifdef SIMULATION
//     HWDATA = y * WIDTH + x;
// `endif
end

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        HADDR <= 0;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && START_IN)
        HADDR <= BASE_ADDR;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE)
        HADDR <= HADDR + 4;

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        HTRANS <= AHB_PKG::TRANS_IDLE;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && START_IN)
        HTRANS <= AHB_PKG::TRANS_NONSEQ;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE && &HADDR[2 +: $clog2(AHB_BURSTS)])
        HTRANS <= HADDR == BASE_ADDR + 4 * WIDTH * HEIGHT - 4 ? AHB_PKG::TRANS_IDLE : AHB_PKG::TRANS_NONSEQ;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE)
        HTRANS <= AHB_PKG::TRANS_SEQ;


endmodule
