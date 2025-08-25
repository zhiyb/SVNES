module NES_DMA #(
    parameter logic [31:0] BASE_ADDR = 32'h08800000,
    parameter H_STRIP  = 800,
    parameter X_OFFSET = 128,
    parameter Y_OFFSET = 128
) (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        PIXEL_VBLANK_IN,
    input  logic        PIXEL_VALID_IN,
    input  logic [23:0] PIXEL_RGB_IN,

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
    input  AHB_PKG::resp_t  HRESP
);

logic vblank_sys;
CDC_ASYNC tp_cdc (
    .CLK        (HCLK),
    .RESET_IN   (HRESET),
    .DATA_IN    (PIXEL_VBLANK_IN),
    .DATA_OUT   (vblank_sys)
);

logic [23:0] pixel_rgb;
logic pixel_req, pixel_ack;
FIFO_ASYNC #(
    .WIDTH  ($bits(PIXEL_RGB_IN))
) fifo_async (
    .WRITE_CLK      (CLK),
    .WRITE_RESET_IN (RESET_IN),
    .WRITE_DATA_IN  (PIXEL_RGB_IN),
    .WRITE_REQ_IN   (PIXEL_VALID_IN),
    .WRITE_ACK_OUT  (),

    .READ_CLK       (HCLK),
    .READ_RESET_IN  (HRESET),
    .READ_DATA_OUT  (pixel_rgb),
    .READ_REQ_OUT   (pixel_req),
    .READ_ACK_IN    (pixel_ack)
);

localparam AHB_BURSTS = 4;
localparam W = 256;

logic [5:0] cnt;

always_ff @(posedge HCLK, posedge HRESET) begin
    if (HRESET) begin
        cnt <= W / AHB_BURSTS - 1;
        HADDR <= BASE_ADDR + X_OFFSET * 4 + Y_OFFSET * H_STRIP * 4;
        HTRANS <= AHB_PKG::TRANS_IDLE;
    end else if (vblank_sys) begin
        // Flush out the in-progress write burst
        cnt <= W / AHB_BURSTS - 1;
        if (HTRANS == AHB_PKG::TRANS_IDLE) begin
            HADDR <= BASE_ADDR + X_OFFSET * 4 + Y_OFFSET * H_STRIP * 4;
        end else if (HTRANS == AHB_PKG::TRANS_BUSY) begin
            HTRANS <= AHB_PKG::TRANS_SEQ;
        end else if (HREADY) begin
            if ((HADDR / 4) % AHB_BURSTS == AHB_BURSTS - 1) begin
                // Last transfer, done
                HTRANS <= AHB_PKG::TRANS_IDLE;
            end else begin
                HADDR <= HADDR + 4;
                HTRANS <= AHB_PKG::TRANS_SEQ;
            end
        end
    end else if (HTRANS == AHB_PKG::TRANS_BUSY) begin
        if (pixel_req)
            HTRANS <= AHB_PKG::TRANS_SEQ;
    end else if (HTRANS == AHB_PKG::TRANS_IDLE) begin
        if (pixel_req)
            HTRANS <= AHB_PKG::TRANS_NONSEQ;
    end else if (HREADY) begin
        if ((HADDR / 4) % AHB_BURSTS == AHB_BURSTS - 1) begin
            cnt <= cnt == 0 ? W / AHB_BURSTS - 1 : cnt - 1;
            HADDR <= HADDR + 4 + (cnt == 0 ? (H_STRIP - W) * 4 : 0);
            HTRANS <= pixel_req ? AHB_PKG::TRANS_NONSEQ : AHB_PKG::TRANS_IDLE;
        end else begin
            HADDR <= HADDR + 4;
            HTRANS <= pixel_req ? AHB_PKG::TRANS_SEQ : AHB_PKG::TRANS_BUSY;
        end
    end
end

assign pixel_ack = HREADY;

assign HBURST = AHB_PKG::BURST_INCR4;
assign HSIZE  = AHB_PKG::SIZE_4;
assign HWRITE = '1;

always_ff @(posedge HCLK, posedge HRESET) begin
    if (HRESET)
        HWDATA <= 0;
    else if (HREADY)
        HWDATA <= {8'b0, pixel_rgb};
end

endmodule
