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
    input  logic [7:0]      START_IN
);

logic start;
logic [7:0] mode;
always_ff @(posedge HCLK, posedge HRESET) begin
    if (HRESET) begin
        start <= 0;
        mode <= 0;
    end else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && START_IN != 0) begin
        start <= 1;
        mode <= START_IN;
    end else begin
        start <= 0;
    end
end

logic data_start;
always_ff @(posedge HCLK, posedge HRESET) begin
    if (HRESET)
        data_start <= 0;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && start)
        data_start <= 1;
    else
        data_start <= 0;
end

assign HBURST = AHB_BURSTS == 8 ? AHB_PKG::BURST_INCR8 :
                AHB_BURSTS == 4 ? AHB_PKG::BURST_INCR4 :
                                  AHB_PKG::BURST_SINGLE;
assign HSIZE  = AHB_PKG::SIZE_4;
// Only write transfers
assign HWRITE = 1;

logic [$clog2(WIDTH)-1:0]  x;
logic [$clog2(HEIGHT)-1:0] y;
always_ff @(posedge HCLK, posedge HRESET) begin
    if (HRESET) begin
        x <= 0;
        y <= 0;
    end else if (data_start) begin
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
    logic [31:0] c;
    HWDATA = 0;
    if (mode[0]) begin
        c = 'h00ff0000;
        HWDATA ^= c;
    end
    if (mode[1]) begin
        c = 'h0000ff00;
        HWDATA ^= c;
    end
    if (mode[2]) begin
        c = 'h000000ff;
        HWDATA ^= c;
    end
    if (mode[3]) begin
        c = 'h0066ccff;
        HWDATA ^= c;
    end
    if (mode[4]) begin
        c = x[0] ^ y[0] ? 'h00ffffff : 0;
        if (x == 4)
            c = 'h0066ccff;
        if (y == 4)
            c = 'h00ff0000;
        HWDATA ^= c;
    end
    if (mode[5]) begin
        c = x[1] ^ y[1] ? 'h00ffffff : 0;
        if (x == 4 || x == 5)
            c = 'h0066ccff;
        if (y == 4 || y == 5)
            c = 'h00ff0000;
        HWDATA ^= c;
    end
    if (mode[6]) begin
        c = x[2] ^ y[2] ? 'h00ffffff : 0;
        if ((x & ~'h3) == 4)
            c = 'h0066ccff;
        if ((y & ~'h3) == 4)
            c = 'h00ff0000;
        HWDATA ^= c;
    end
    if (mode[7]) begin
        localparam LINE = 2;
        c = {y[0 +: 8], x[0 +: 8], {8{x[0] ^ y[0]}}};
        if (x == 0)
            c = 'hff0000;
        else if (x == WIDTH - 1)
            c = 'h00ffff;
        else if (y == 0)
            c = 'h00ff00;
        else if (y == HEIGHT - 1)
            c = 'hff00ff;
        if (x >= WIDTH  / 2 - LINE && x < WIDTH      / 2 + LINE &&
            y >= HEIGHT / 4 - LINE && y < HEIGHT * 3 / 4 + LINE)
            c = {24{x[1] ^ y[1]}};
        if (x >= WIDTH  / 4 - LINE && x < WIDTH  * 3 / 4 + LINE &&
            y >= HEIGHT / 2 - LINE && y < HEIGHT     / 2 + LINE)
            c = {24{x[1] ^ y[1]}};
        HWDATA ^= c;
    end
end

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        HADDR <= 0;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && start)
        HADDR <= BASE_ADDR;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE)
        HADDR <= HADDR + 4;

always_ff @(posedge HCLK, posedge HRESET)
    if (HRESET)
        HTRANS <= AHB_PKG::TRANS_IDLE;
    else if (HREADY && HTRANS == AHB_PKG::TRANS_IDLE && start)
        HTRANS <= AHB_PKG::TRANS_NONSEQ;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE && &HADDR[2 +: $clog2(AHB_BURSTS)])
        HTRANS <= HADDR == BASE_ADDR + 4 * WIDTH * HEIGHT - 4 ? AHB_PKG::TRANS_IDLE : AHB_PKG::TRANS_NONSEQ;
    else if (HREADY && HTRANS != AHB_PKG::TRANS_IDLE)
        HTRANS <= AHB_PKG::TRANS_SEQ;


endmodule
