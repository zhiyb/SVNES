module SDRAM_FIFO #(
    parameter int N_PORTS  = 4,
    parameter int N_BURSTS = 8
) (
    input wire CLK,
    input wire RESET_IN,

    // Upstream ports
    input  logic                    [N_PORTS-1:0] SRC_WRITE_IN,
    input  SDRAM_PKG::dram_access_t [N_PORTS-1:0] SRC_ACS_IN,
    output SDRAM_PKG::data_t        [N_PORTS-1:0] SRC_DATA_OUT,
    input  logic                    [N_PORTS-1:0] SRC_REQ_IN,
    output logic                    [N_PORTS-1:0] SRC_ACK_OUT,

    // Downstream ports
    output logic                    [N_PORTS-1:0] DST_WRITE_OUT,
    output SDRAM_PKG::dram_access_t [N_PORTS-1:0] DST_ACS_OUT,
    input  SDRAM_PKG::data_t        [N_PORTS-1:0] DST_DATA_IN,
    output logic                    [N_PORTS-1:0] DST_REQ_OUT,
    input  logic                    [N_PORTS-1:0] DST_ACK_IN
);

generate
    genvar i;
    for (i = 0; i < N_PORTS; i++) begin: gen_port

        logic fifo_req, fifo_ack;

        FIFO_SYNC #(
            .WIDTH      ($bits(SDRAM_PKG::dram_access_t) + 1),
            .DEPTH_LOG2 (1)
        ) w_fifo (
            .CLK            (CLK),
            .RESET_IN       (RESET_IN),

            .WRITE_DATA_IN  ({SRC_WRITE_IN[i], SRC_ACS_IN[i]}),
            .WRITE_REQ_IN   (fifo_req),
            .WRITE_ACK_OUT  (fifo_ack),

            .READ_DATA_OUT  ({DST_WRITE_OUT[i], DST_ACS_OUT[i]}),
            .READ_REQ_OUT   (DST_REQ_OUT[i]),
            .READ_ACK_IN    (DST_ACK_IN[i])
        );

        always_ff @(posedge CLK)
            SRC_DATA_OUT[i] <= DST_DATA_IN[i];

        // For read bursts, fudge SRC REQ & ACK
        localparam READ_DELAY = 2;

        logic [$clog2(N_BURSTS+READ_DELAY-1)-1:0] burst_cnt;

        always_ff @(posedge CLK, posedge RESET_IN)
            if (RESET_IN)
                burst_cnt <= 0;
            else if (~SRC_WRITE_IN[i] & SRC_REQ_IN[i] & fifo_ack) begin
                if (burst_cnt == 0)
                    burst_cnt <= N_BURSTS + READ_DELAY;
                else
                    burst_cnt <= burst_cnt - 1;
            end

        assign fifo_req       = SRC_REQ_IN[i] &&
                                (SRC_WRITE_IN[i] || burst_cnt > READ_DELAY);
        assign SRC_ACK_OUT[i] = fifo_ack &&
                                (SRC_WRITE_IN[i] || (burst_cnt > 0 && burst_cnt <= N_BURSTS));

    end: gen_port
endgenerate

endmodule
