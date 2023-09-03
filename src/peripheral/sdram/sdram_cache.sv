module SDRAM_CACHE #(
    parameter int N_LINES = 8,
    parameter int N_SRC   = 4,
    parameter int N_DST   = 4,
    parameter int BURST   = 8
) (
    input wire CLK,
    input wire RESET_IN,

    // Upstream AHB ports
    input  AHB_PKG::addr_t  [N_SRC-1:0] HADDR,
    input  AHB_PKG::burst_t [N_SRC-1:0] HBURST,
    input  AHB_PKG::size_t  [N_SRC-1:0] HSIZE,
    input  AHB_PKG::trans_t [N_SRC-1:0] HTRANS,
    input  logic            [N_SRC-1:0] HWRITE,
    input  AHB_PKG::data_t  [N_SRC-1:0] HWDATA,
    output AHB_PKG::data_t  [N_SRC-1:0] HRDATA,
    output logic            [N_SRC-1:0] HREADY,
    output AHB_PKG::resp_t  [N_SRC-1:0] HRESP,

    // Downstream ports
    output logic                    [N_DST-1:0] DST_WRITE_OUT,
    output SDRAM_PKG::dram_access_t [N_DST-1:0] DST_ACS_OUT,
    input  SDRAM_PKG::data_t        [N_DST-1:0] DST_DATA_IN,
    output logic                    [N_DST-1:0] DST_REQ_OUT,
    input  logic                    [N_DST-1:0] DST_ACK_IN
);

localparam AHB_BYTES      = $bits(AHB_PKG::data_t) / 8;
localparam LINE_FETCHES   = BURST;
localparam LINE_BYTES     = LINE_FETCHES * $bits(SDRAM_PKG::data_t) / 8;
localparam LINE_ADDR_BITS = $clog2(LINE_BYTES);
localparam TAG_INDEX_BITS = $clog2(N_LINES);
localparam TAG_ADDR_BITS  = $clog2(SDRAM_PKG::MAX_BYTES) - LINE_ADDR_BITS - TAG_INDEX_BITS;

typedef logic [TAG_ADDR_BITS-1:0]        tag_addr_t;
typedef logic [TAG_INDEX_BITS-1:0]       index_addr_t;
typedef logic [LINE_ADDR_BITS-1:0]       data_addr_t;
typedef logic [LINE_BYTES*8-1:0]         line_data_t;
typedef logic [$clog2(LINE_FETCHES)-1:0] fetch_ofs_t;

typedef struct packed {
    tag_addr_t   tag;
    index_addr_t index;
    data_addr_t  ofs;
} src_addr_t;


// SRC states
src_addr_t        [N_SRC-1:0] src_addr;
AHB_PKG::size_t   [N_SRC-1:0] src_size;
logic             [N_SRC-1:0] src_fetch_req;
logic             [N_SRC-1:0] src_write_req;
logic             [N_SRC-1:0] [N_LINES-1:0] src_req;


// Line states
tag_addr_t        [N_LINES-1:0] tag;
line_data_t       [N_LINES-1:0] data;
logic             [N_LINES-1:0] dirty;
logic             [N_LINES-1:0] pending;
logic             [N_LINES-1:0] valid;

// From/To DST
logic             [N_LINES-1:0] fetch_req;
logic             [N_LINES-1:0] fetch_acpt;     // todo
tag_addr_t        [N_LINES-1:0] fetch_tag;
SDRAM_PKG::data_t [N_LINES-1:0] data_fetched;   // todo
fetch_ofs_t       [N_LINES-1:0] data_ofs;       // todo
logic             [N_LINES-1:0] data_valid;     // todo
logic             [N_LINES-1:0] last_data;
logic             [N_LINES-1:0] write_req;
logic             [N_LINES-1:0] write_acpt;     // todo


// DST states


generate
    genvar isrc;
    for (isrc = 0; isrc < N_SRC; isrc++) begin: gen_src

        logic src_imm_htrans;

        index_addr_t src_index;
        logic src_tag_match;
        logic src_write;

        assign src_index = src_addr[isrc].index;
        assign src_tag_match = valid[src_index] && tag[src_index] == src_addr[isrc].tag;
        assign src_imm_htrans = !(HTRANS[isrc] inside {AHB_PKG::TRANS_IDLE, AHB_PKG::TRANS_BUSY});

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                src_addr[isrc] <= 0;
                src_size[isrc] <= AHB_PKG::SIZE_4;
                src_write <= 0;
            end else if (HREADY[isrc]) begin
                src_addr[isrc] <= HADDR[isrc];
                src_size[isrc] <= HSIZE[isrc];
                src_write <= HWRITE[isrc];
            end
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                HREADY[isrc] <= 1;
            end else if (HREADY[isrc]) begin
                HREADY[isrc] <= !src_imm_htrans;
            end else if (src_write) begin
                HREADY[isrc] <= 0;
                // Waiting for pending fetch not supported yet
                if (src_tag_match)
                    HREADY[isrc] <= 1;
            end else begin
                HREADY[isrc] <= 0;
                if (src_tag_match)
                    HREADY[isrc] <= 1;
            end
        end

        AHB_PKG::data_t src_data;
        always_comb begin
            data_addr_t ofs;
            ofs = src_addr[isrc].ofs;
            ofs[$clog2(AHB_BYTES)-1:0] = 0;
            src_data = data[src_index][8*ofs +: $bits(src_data)];
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN)
                HRDATA <= 0;
            else
                HRDATA <= src_data;
        end

        assign HRESP[isrc]  = AHB_PKG::RESP_OKAY;

        assign src_fetch_req[isrc] = !src_tag_match;
        assign src_write_req[isrc] = src_write;

        always_comb begin
            int il;
            logic sreq;
            sreq = !HREADY[isrc] && (src_fetch_req[isrc] || src_write_req[isrc]);
            src_req[isrc] = 0;
            for (il = 0; il < N_LINES; il++)
                src_req[isrc][il] = sreq && src_index == il;
        end

    end: gen_src

    genvar iline;
    for (iline = 0; iline < N_LINES; iline++) begin: gen_line

        // From/To SRC
        logic [N_SRC-1:0] line_src_fetch_req;
        logic [N_SRC-1:0] line_src_fetch_grant;

        // SRC arbiter
        always_comb begin
            int is;

            line_src_fetch_req = 0;
            for (is = 0; is < N_SRC; is++)
                line_src_fetch_req[is] = src_req[is][iline] && src_fetch_req[is];

            line_src_fetch_grant = 0;
            for (is = 0; is < N_SRC; is++) begin
                if (line_src_fetch_req[is]) begin
                    line_src_fetch_grant[is] = 1;
                    break;
                end
            end
        end

        logic any_write;
        logic any_fetch;
        always_comb begin
            int is;
            any_write = 0;
            any_fetch = 0;
            for (is = 0; is < N_SRC; is++) begin
                // A non-fetch req is a write req
                if (src_req[is][iline] && !src_fetch_req[is])
                    any_write = 1;
                if (src_req[is][iline] && src_fetch_req[is])
                    any_fetch = 1;
            end
        end

        always_comb begin
            int is;
            tag_addr_t ftag;
            ftag = 0;
            for (is = 0; is < N_SRC; is++) begin
                if (line_src_fetch_grant[is])
                    ftag |= src_addr[is].tag;
            end
            fetch_tag[iline] = any_fetch ? ftag : tag[iline];
        end

        // State transitions
        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                dirty[iline]   <= 0;
                pending[iline] <= 0;
            end else begin
                if (any_write) begin
                    // If any write request exists, always accept and mark as dirty
                    dirty[iline] <= 1;
                    // And abort any pending fetch req
                    pending[iline] <= 0;
                end else if (dirty[iline]) begin
                    // If got fetch req from SRC, check write req accepted by DST, then clean
                    dirty[iline] <= !(write_req[iline] && write_acpt[iline]);
                end else if (pending[iline]) begin
                    // If all data is received from DST, clear pending state
                    pending[iline] <= !(data_valid[iline] && last_data[iline]);
                end else begin
                    // In idle valid state, and no write req, check for fetch req, then go pending
                    pending[iline] <= fetch_req[iline] && fetch_acpt[iline];
                end
            end
        end

        always_comb begin
            fetch_req[iline] = 0;
            write_req[iline] = 0;
            if (any_write) begin
                // Doing dirty, do not send any DST req
            end else if (dirty[iline]) begin
                // Clean (DST write) if SRC asking for fetch
                write_req[iline] = any_fetch;
            end else if (pending[iline]) begin
                // Waiting for fetched data
            end else begin
                // Clean, no write req, check for fetch req
                fetch_req[iline] = any_fetch;
            end
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                tag[iline]   <= 0;
                valid[iline] <= 1;
                data[iline]  <= 0;
            end else if (!any_write && data_valid[iline]) begin
                // Received fetched data
                // Note, pending fetch req gets aborted by write req
                tag[iline]   <= fetch_tag[iline];
                valid[iline] <= last_data[iline];
                data[iline][data_ofs[iline]*$bits(SDRAM_PKG::data_t) +: $bits(SDRAM_PKG::data_t)] <= data_fetched[iline];
            end else begin
                // Check for write requests
                int is;
                for (is = 0; is < N_SRC; is++) begin
                    // A non-fetch req is a write req
                    if (src_req[is][iline] && !src_fetch_req[is]) begin
                        if (src_size[is] == AHB_PKG::SIZE_4) begin
                            data_addr_t aligned_ofs;
                            aligned_ofs = src_addr[is].ofs;
                            aligned_ofs[1:0] = 0;
                            data[iline][aligned_ofs*8 +: 4*8] <= HWDATA[is];
                        end
                    end
                end
            end
        end

        assign last_data[iline] = data_ofs[iline] == LINE_FETCHES-1;

        // TODO
        assign fetch_acpt[iline] = 1;
        assign write_acpt[iline] = 1;
        assign data_ofs[iline] = LINE_FETCHES-1;
        assign data_fetched[iline] = 0;

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN)
                data_valid[iline] = 0;
            else
                data_valid[iline] = fetch_req[iline];
        end

    end: gen_line

    genvar idst;
    for (idst = 0; idst < N_DST; idst++) begin: gen_dst
    end: gen_dst
endgenerate

endmodule
