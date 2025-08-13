module TFT_MAPPING #(
    // Pixel RGB output width
    parameter TFT_WIDTH = 24
) (
    input  wire CLK,
    input  wire RESET_IN,

    // DMA data input
    input  logic [31:0]          DATA_IN,
    input  logic                 REQ_IN,
    output logic                 ACK_OUT,

    // TFT data output
    output logic [TFT_WIDTH-1:0] DATA_OUT,
    output logic                 REQ_OUT,
    input  logic                 ACK_IN,

    // DMA restarts after VSYNC
    input  logic                 VSYNC_IN
);

localparam MAPPING_BYTES = 2;

logic [6:0][7:0] data, data_new;
logic [$clog2(8)-1:0] ofs, ofs_new;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        data <= 0;
        ofs <= 0;
    end else if (VSYNC_IN) begin
        data <= 0;
        ofs <= 0;
    end else begin
        data <= data_new;
        ofs <= ofs_new;
    end
end

always_comb begin
    data_new = data;
    ofs_new = ofs;
    if (REQ_OUT && ACK_IN) begin
        data_new = data_new[6:MAPPING_BYTES];
        ofs_new -= MAPPING_BYTES;
    end
    if (REQ_IN && ACK_OUT) begin
        data_new[6:4] = data_new[2:0];
        data_new[3:0] = DATA_IN;
        ofs_new += 4;
    end
end

assign REQ_OUT  = ofs >= MAPPING_BYTES;
assign ACK_OUT  = ofs < $bits(DATA_IN) / 8;

// RGB mapping logic

logic [15:0] data_565;
assign data_565 = data[1:0];
logic [23:0] rgb565;
assign rgb565 = {data_565[11 +: 5], 3'b0, data_565[5 +: 6], 2'b0, data_565[0 +: 5], 3'b0};

assign DATA_OUT = rgb565;

endmodule
