module SDRAM_AHB_ARB #(
    parameter AHB_PORTS = 4,
    parameter N_BANKS   = SDRAM_PKG::N_BANKS,
    parameter BURST     = 8
) (
    input wire CLK,
    input wire RESET_IN,

    // Upstream ports
    input  logic                    [AHB_PORTS-1:0] BURST_WRITE_IN,
    input  SDRAM_PKG::dram_access_t [AHB_PORTS-1:0] BURST_ACS_IN,
    input  logic                    [AHB_PORTS-1:0] BURST_REQ_IN,
    output logic                    [AHB_PORTS-1:0] BURST_ACK_OUT,
    input  SDRAM_PKG::data_t        [AHB_PORTS-1:0] BURST_WRITE_DATA_IN,
    output logic                    [AHB_PORTS-1:0] BURST_VALID_OUT,
    output SDRAM_PKG::data_t        [AHB_PORTS-1:0] BURST_READ_DATA_OUT,

    // Downstream per-bank ports
    output logic                    [N_BANKS-1:0] BANK_WRITE_OUT,
    output SDRAM_PKG::dram_access_t [N_BANKS-1:0] BANK_ACS_OUT,
    output logic                    [N_BANKS-1:0] BANK_REQ_OUT,
    input  logic                    [N_BANKS-1:0] BANK_ACK_IN,
    output SDRAM_PKG::data_t        [N_BANKS-1:0] BANK_WRITE_DATA_OUT,

    // SDRAM read back data
    input  SDRAM_PKG::data_t READ_DATA_IN,
    input  logic             READ_VALID_IN
);

typedef struct packed {
    logic [AHB_PORTS-1:0] sel, req;
} bank_t;
bank_t [N_BANKS-1:0] bank;

generate
    genvar ba;
    for (ba = 0; ba < N_BANKS; ba++) begin: gen_bank
        logic [AHB_PORTS-1:0] req_in;
        always_comb begin
            int ahb;
            req_in = 0;
            for (ahb = 0; ahb < AHB_PORTS; ahb++) begin
                if (BURST_REQ_IN[ahb] && BURST_ACS_IN[ahb].bank == ba) begin
                    req_in[ahb] = 1;
                    break;
                end
            end
        end

        logic [$clog2(BURST)-1:0] write_burst;
        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN)
                write_burst <= 0;
            else if (BANK_REQ_OUT[ba])
                write_burst <= BANK_WRITE_OUT[ba] ? BURST - 1 : 0;
            else if (write_burst)
                write_burst <= write_burst - 1;
        end

        logic [AHB_PORTS-1:0] sel, req;
        assign bank[ba].sel = sel;
        assign bank[ba].req = req;
        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                sel <= 0;
                req <= 0;
            end else if (sel == 0) begin
                sel <= req_in;
                req <= req_in;
            end else if (BANK_ACK_IN[ba]) begin
                // req_in needs one cycle to update, so clear to 0 for now
                if (write_burst == 0) begin
                    sel <= 0;
                    req <= 0;
                end else begin
                    // sel still needed for routing write burst data
                    req <= 0;
                end
            end else if (req == 0 && write_burst == 0) begin
                sel <= req_in;
                req <= req_in;
            end
        end

        always_comb begin
            int ahb;
            BANK_REQ_OUT[ba]        = 0;
            BANK_ACS_OUT[ba]        = SDRAM_PKG::dram_access_t'(0);
            BANK_WRITE_OUT[ba]      = 0;
            BANK_WRITE_DATA_OUT[ba] = 0;
            for (ahb = 0; ahb < AHB_PORTS; ahb++) begin
                if (sel[ahb]) begin
                    BANK_REQ_OUT[ba]        |= req[ahb];
                    BANK_ACS_OUT[ba]        |= BURST_ACS_IN[ahb];
                    BANK_WRITE_OUT[ba]      |= BURST_WRITE_IN[ahb];
                    BANK_WRITE_DATA_OUT[ba] |= BURST_WRITE_DATA_IN[ahb];
                end
            end
        end
    end: gen_bank

    genvar ahb;
    for (ahb = 0; ahb < AHB_PORTS; ahb++) begin: gen_ahb
        always_comb begin
            int ba;
            BURST_ACK_OUT[ahb] = 0;
            for (ba = 0; ba < N_BANKS; ba++) begin
                if (bank[ba].req[ahb])
                    BURST_ACK_OUT[ahb] |= BANK_ACK_IN[ba];
            end
        end
    end: gen_ahb
endgenerate

// Record read requests
logic [$clog2(AHB_PORTS)-1:0] fifo_write_data, fifo_read_data;
logic fifo_write_req, fifo_read_req, fifo_read_ack;

FIFO_SYNC #(
    .WIDTH ($clog2(AHB_PORTS)),
    .DEPTH (N_BANKS)
) fifo (
    .CLK                (CLK),
    .RESET_IN           (RESET_IN),
    .WRITE_DATA_IN      (fifo_write_data),
    .WRITE_REQ_IN       (fifo_write_req),
    .WRITE_ACK_OUT      (),
    .WRITE_THRES_OUT    (),
    .READ_DATA_OUT      (fifo_read_data),
    .READ_REQ_OUT       (fifo_read_req),
    .READ_ACK_IN        (fifo_read_ack),
    .READ_THRES_OUT     ()
);

assign fifo_write_req = |{BANK_ACK_IN & ~BANK_WRITE_OUT};

always_comb begin
    int ba;
    fifo_write_data = 0;
    for (ba = 0; ba < N_BANKS; ba++) begin
        if (BANK_ACK_IN[ba]) begin
            int ahb;
            for (ahb = 0; ahb < AHB_PORTS; ahb++)
                if (bank[ba].req[ahb])
                    fifo_write_data |= ahb;
        end
    end
end

assign fifo_read_ack = READ_VALID_IN;
assign BURST_VALID_OUT = fifo_read_ack ? 1 << fifo_read_data : 0;
assign BURST_READ_DATA_OUT = {AHB_PORTS{READ_DATA_IN}};

endmodule
