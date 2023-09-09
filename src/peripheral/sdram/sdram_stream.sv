// AHB stream port that only supports fixed BURST length

module SDRAM_STREAM #(
    parameter int BURST = 8
) (
    input wire CLK,
    input wire RESET_IN,

    // Upstream AHB ports
    input  AHB_PKG::addr_t  HADDR,
    input  AHB_PKG::burst_t HBURST,
    input  AHB_PKG::size_t  HSIZE,
    input  AHB_PKG::trans_t HTRANS,
    input  logic            HWRITE,
    input  AHB_PKG::data_t  HWDATA,
    output AHB_PKG::data_t  HRDATA,
    output logic            HREADY,
    output AHB_PKG::resp_t  HRESP,

    // Downstream ports
    output logic                    DST_WRITE_OUT,
    output SDRAM_PKG::dram_access_t DST_ACS_OUT,
    input  SDRAM_PKG::data_t        DST_DATA_IN,
    output logic                    DST_REQ_OUT,
    input  logic                    DST_ACK_IN
);

localparam int AHB_BURSTS = BURST * $bits(SDRAM_PKG::data_t) / $bits(AHB_PKG::data_t);
localparam AHB_PKG::burst_enum_t HBURST_TYPE = AHB_BURSTS == 8 ? AHB_PKG::BURST_INCR8 :
                                               AHB_BURSTS == 4 ? AHB_PKG::BURST_INCR4 :
                                                                 AHB_PKG::BURST_INCR;

logic [$bits(SDRAM_PKG::data_t)*BURST-1:0] data;

AHB_PKG::addr_t haddr;
logic [$clog2(AHB_BURSTS)-1:0] hofs;
logic hstore;
logic htrans;

logic [$clog2(BURST)-1:0] dofs;
logic dstore;
logic ddone;


always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        data <= 0;
    else if (hstore)
        data[hofs*$bits(AHB_PKG::data_t) +: $bits(AHB_PKG::data_t)] <= HWDATA;
    else if (dstore)
        data[dofs*$bits(SDRAM_PKG::data_t) +: $bits(SDRAM_PKG::data_t)] <= DST_DATA_IN;
`ifdef SIMULATION
    else if (HREADY && HTRANS == AHB_PKG::TRANS_NONSEQ)
        data <= 'x;
`endif


always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        haddr <= 0;
        hstore <= 0;
    end else if (HREADY) begin
        haddr <= HADDR;
        hstore <= htrans && HWRITE;
    end else begin
        hstore <= 0;
    end
end

assign htrans = HTRANS != AHB_PKG::TRANS_IDLE &&
                HTRANS != AHB_PKG::TRANS_BUSY;
assign hofs = haddr[2 +: $bits(hofs)];
assign HRDATA = data[hofs*$bits(AHB_PKG::data_t) +: $bits(AHB_PKG::data_t)];

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        HREADY <= 1;
    end else if (HREADY) begin
        if (~htrans)
            HREADY <= 1;
        else if (HWRITE)
            HREADY <= ~&HADDR[2 +: $bits(hofs)];    // Wait for DST write at the last burst beat
        else
            HREADY <= |HADDR[2 +: $bits(hofs)];     // Wait for DST read at the first burst beat
    end else begin
        HREADY <= ddone;
    end
end

assign HRESP = AHB_PKG::RESP_OKAY;


always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        DST_REQ_OUT <= 0;
        DST_WRITE_OUT <= 0;
    end else if (hstore && &hofs) begin
        DST_REQ_OUT <= 1;
        DST_WRITE_OUT <= 1;
    end else if (HREADY && ~HWRITE && HTRANS == AHB_PKG::TRANS_NONSEQ) begin
        DST_REQ_OUT <= 1;
        DST_WRITE_OUT <= 0;
    end else if (DST_REQ_OUT && DST_ACK_IN && &dofs) begin
        DST_REQ_OUT <= 0;
    end
end

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        dofs <= 0;
    end else if (HREADY && HTRANS == AHB_PKG::TRANS_NONSEQ) begin
        dofs <= 0;
    end else if (DST_REQ_OUT && DST_ACK_IN) begin
        dofs <= dofs + 1;
    end
end

assign dstore = DST_REQ_OUT & DST_ACK_IN & ~DST_WRITE_OUT;
assign ddone = DST_REQ_OUT & DST_ACK_IN & &dofs;

always_comb begin
    AHB_PKG::addr_t addr;
    DST_ACS_OUT = 0;
    addr = haddr;
    addr >>= $clog2($bits(SDRAM_PKG::data_t)/8);
    {DST_ACS_OUT.bank, DST_ACS_OUT.row, DST_ACS_OUT.col} = addr;
    DST_ACS_OUT.col[$bits(dofs)-1:0] = dofs;
    DST_ACS_OUT.data = data[dofs*$bits(SDRAM_PKG::data_t) +: $bits(SDRAM_PKG::data_t)];
`ifdef SIMULATION
    if (~DST_WRITE_OUT)
        DST_ACS_OUT.data = 'x;
    if (~DST_REQ_OUT)
        DST_ACS_OUT = 'x;
`endif
end

`ifdef SIMULATION
    always_ff @(posedge CLK) begin
        if (HREADY && htrans) begin
            assert (HBURST == HBURST_TYPE)
            else $error("Unexpected burst type");
            assert (HSIZE == AHB_PKG::SIZE_4)
            else $error("Unexpected size");
        end
    end
`endif

endmodule
