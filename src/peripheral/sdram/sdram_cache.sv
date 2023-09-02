module SDRAM_CACHE #(
    parameter int N_LINES = 8,
    parameter int N_SRC   = 4,
    parameter int N_DST   = 4,
    parameter int BURST   = 8
) (
    input wire CLK,
    input wire RESET_IN,

    // Upstream AHB ports
    input  logic [31:0]     HADDR  [N_SRC-1:0],
    input  AHB_PKG::burst_t HBURST [N_SRC-1:0],
    input  AHB_PKG::size_t  HSIZE  [N_SRC-1:0],
    input  AHB_PKG::trans_t HTRANS [N_SRC-1:0],
    input  logic            HWRITE [N_SRC-1:0],
    input  logic [31:0]     HWDATA [N_SRC-1:0],
    output logic [31:0]     HRDATA [N_SRC-1:0],
    output logic            HREADY [N_SRC-1:0],
    output AHB_PKG::resp_t  HRESP  [N_SRC-1:0],

    // Downstream ports
    output logic                    [N_DST-1:0] DST_WRITE_OUT,
    output SDRAM_PKG::dram_access_t [N_DST-1:0] DST_ACS_OUT,
    input  SDRAM_PKG::data_t        [N_DST-1:0] DST_DATA_IN,
    output logic                    [N_DST-1:0] DST_REQ_OUT,
    input  logic                    [N_DST-1:0] DST_ACK_IN
);

localparam LINE_BYTES     = BURST * $bits(SDRAM_PKG::data_t) / 8;
localparam LINE_ADDR_BITS = $clog2(LINE_BYTES);
localparam TAG_INDEX_BITS = $clog2(N_LINES);
localparam TAG_ADDR_BITS  = $clog2(SDRAM_PKG::MAX_BYTES) - LINE_ADDR_BITS - TAG_INDEX_BITS;

typedef logic [TAG_ADDR_BITS-1:0]   tag_addr_t;
typedef logic [TAG_INDEX_BITS-1:0]  index_addr_t;
typedef logic [LINE_ADDR_BITS-1:0]  data_addr_t;
typedef logic [LINE_BYTES-1:0][7:0] line_data_t;

typedef struct packed {
    tag_addr_t tag;
    line_data_t data;
    logic [N_SRC-1:0] src_req, src_grant;
    logic pending;
    logic valid, dirty;
} line_t;

typedef struct packed {
    tag_addr_t   tag;
    index_addr_t index;
    data_addr_t  ofs;
} src_addr_t;

/* verilator lint_off UNOPTFLAT */
line_t line [N_LINES-1:0];
/* verilator lint_on UNOPTFLAT */

generate
    genvar isrc;
    for (isrc = 0; isrc < N_SRC; isrc++) begin: gen_src
        src_addr_t src_addr;
        line_t src_line;

        assign src_addr = HADDR[isrc];
        assign src_line = line[src_addr.index];

        always_comb begin
            logic req;
            int i;
            req = 0;
            if (HTRANS[isrc] != AHB_PKG::TRANS_IDLE) begin
                if (src_line.valid && src_line.tag == src_addr.tag)
                    req = 0;
                else
                    req = 1;
            end
            for (i = 0; i < N_LINES; i++)
                line[i].src_req[isrc] = req && src_addr.index == i;
        end

        // TODO
        assign HREADY[isrc] = HTRANS[isrc] == AHB_PKG::TRANS_IDLE ||
                              src_line.src_grant[isrc];
        assign HRESP[isrc]  = AHB_PKG::RESP_OKAY;
    end: gen_src

    genvar iline;
    for (iline = 0; iline < N_LINES; iline++) begin: gen_line
        always_comb begin
            int i;
            line[iline].src_grant = 0;
            for (i = 0; i < N_SRC; i++) begin
                if (line[iline].src_req[i]) begin
                    line[iline].src_grant[i] = 1;
                    break;
                end
            end
            line[iline].src_grant = line[iline].src_req;
        end
    end: gen_line
endgenerate

endmodule
