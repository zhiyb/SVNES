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

localparam AHB_BYTES       = $bits(AHB_PKG::data_t) / 8;
localparam LINE_FETCHES    = BURST;
localparam LINE_BYTES      = LINE_FETCHES * $bits(SDRAM_PKG::data_t) / 8;
localparam LINE_ADDR_BITS  = $clog2(LINE_BYTES);
localparam TAG_INDEX_BITS  = $clog2(N_LINES);
localparam TAG_ADDR_BITS   = $clog2(SDRAM_PKG::MAX_BYTES) - LINE_ADDR_BITS - TAG_INDEX_BITS;
localparam FETCH_ADDR_BITS = $clog2(LINE_FETCHES);

typedef logic [TAG_ADDR_BITS-1:0]   tag_addr_t;
typedef logic [TAG_INDEX_BITS-1:0]  index_addr_t;
typedef logic [LINE_ADDR_BITS-1:0]  data_addr_t;
typedef logic [LINE_BYTES*8-1:0]    line_data_t;
typedef logic [FETCH_ADDR_BITS-1:0] fetch_ofs_t;

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

// From/To DST
logic             [N_LINES-1:0] fetch_req;
logic             [N_LINES-1:0] fetch_acpt;
tag_addr_t        [N_LINES-1:0] req_tag;
line_data_t       [N_LINES-1:0] data_fetched;
logic             [N_LINES-1:0] data_valid;
logic             [N_LINES-1:0] write_req;
logic             [N_LINES-1:0] write_acpt;


// DST states
logic             [N_DST-1:0] [N_LINES-1:0] dst_req;
logic             [N_DST-1:0] [N_LINES-1:0] dst_grant;
logic             [N_DST-1:0] dst_busy;
tag_addr_t        [N_DST-1:0] dst_tag;
index_addr_t      [N_DST-1:0] dst_index;
fetch_ofs_t       [N_DST-1:0] dst_ofs;
line_data_t       [N_DST-1:0] dst_data;
logic             [N_DST-1:0] dst_valid;


generate
    genvar isrc;
    for (isrc = 0; isrc < N_SRC; isrc++) begin: gen_src

        logic src_imm_htrans;

        index_addr_t src_index;
        logic src_tag_match;
        logic src_write;

        assign src_index = src_addr[isrc].index;
        assign src_tag_match = tag[src_index] == src_addr[isrc].tag;
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
            req_tag[iline] = any_fetch ? ftag : tag[iline];
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
                    pending[iline] <= !(data_valid[iline]);
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
                // Going dirty, do not send any DST req
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
                tag[iline]  <= 0;
                data[iline] <= 0;
            end else if (!any_write && data_valid[iline]) begin
                // Received fetched data
                // Note, pending fetch req gets aborted by write req
                tag[iline]  <= req_tag[iline];
                data[iline] <= data_fetched[iline];
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

        always_comb begin
            int id;
            fetch_acpt[iline] = 0;
            write_acpt[iline] = 0;
            for (id = 0; id < N_DST; id++) begin
                if (dst_grant[id][iline]) begin
                    fetch_acpt[iline] |= 1;
                    write_acpt[iline] |= 1;
                end
            end
        end

        always_comb begin
            int id;
            data_valid[iline] = 0;
            data_fetched[iline] = 0;
            for (id = 0; id < N_DST; id++) begin
                if (dst_valid[id] && dst_index[id] == iline) begin
                    data_valid[iline] = 1;
                    data_fetched[iline] = dst_data[id];
                end
            end
        end

    end: gen_line

    always_comb begin
        int il, id;
        il = 0;
        id = 0;
        dst_req = 0;
        for (il = 0; il < N_LINES; il++) begin
            for (; id < N_DST; id++)
                if (!dst_busy[id])
                    break;
            if (id >= N_DST) begin
            end else if (fetch_req[il] || write_req[il]) begin
                dst_req[id][il] = 1;
                id++;
            end
        end
    end

    genvar idst;
    for (idst = 0; idst < N_DST; idst++) begin: gen_dst

        logic dst_fetch_req;
        logic dst_write_req;
        tag_addr_t dst_req_tag;
        index_addr_t dst_req_index;
        fetch_ofs_t dst_ofs_out;
        line_data_t dst_write_data;
        SDRAM_PKG::dram_access_t dst_acs;

        logic [31:0] dst_base_addr;
        logic [31:0] dst_base_addr_out;

        line_data_t dst_data_out;

        always_comb begin
            int il;
            dst_fetch_req = 0;
            dst_write_req = 0;
            dst_grant[idst] = 0;
            dst_req_tag = 0;
            dst_req_index = 0;
            dst_write_data = 0;
            for (il = 0; il < N_LINES; il++) begin
                if (dst_req[idst][il]) begin
                    dst_fetch_req |= fetch_req[il];
                    dst_write_req |= write_req[il];
                    dst_grant[idst][il] = !DST_REQ_OUT[idst];
                    dst_req_tag |= req_tag[il];
                    dst_req_index |= il;
                    dst_write_data |= data[il];
                end
            end
        end

        always_comb begin
            logic [31:0] dst_base_addr_out_tmp;
            data_addr_t dst_data_addr_out_tmp;
            // Address mapping for write address
            dst_base_addr = {dst_req_tag, dst_req_index, data_addr_t'(0)};
            dst_base_addr >>= $clog2($bits(SDRAM_PKG::data_t)/8);
            // Reverted address mapping for read address
            dst_base_addr_out_tmp = dst_base_addr_out;
            dst_base_addr_out_tmp <<= $clog2($bits(SDRAM_PKG::data_t)/8);
            {dst_tag[idst], dst_index[idst], dst_data_addr_out_tmp} = dst_base_addr_out_tmp;
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                dst_base_addr_out <= 0;
            end else if (dst_grant[idst]) begin
                dst_base_addr_out <= dst_base_addr;
            end
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                dst_data[idst] <= 0;
            end else if (dst_grant[idst] && dst_write_req) begin
                dst_data[idst] <= dst_write_data;
            end else if (!DST_WRITE_OUT[idst] && DST_ACK_IN[idst]) begin
                dst_data[idst][dst_ofs[idst]*$bits(SDRAM_PKG::data_t) +: $bits(SDRAM_PKG::data_t)] <= DST_DATA_IN[idst];
            end
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN)
                dst_valid[idst] <= 0;
            else
                dst_valid[idst] <= !DST_WRITE_OUT[idst] && DST_ACK_IN[idst] && dst_ofs[idst] == LINE_FETCHES-1;
        end

        assign dst_busy[idst] = DST_REQ_OUT[idst];

        // dst_data and dst_ofs used for both read & write data latch
        assign dst_data_out = dst_data[idst];
        assign dst_ofs[idst] = dst_ofs_out;

        always_comb begin
            DST_ACS_OUT[idst] = 0;
            {DST_ACS_OUT[idst].bank, DST_ACS_OUT[idst].row, DST_ACS_OUT[idst].col} = dst_base_addr_out;
            DST_ACS_OUT[idst].col[$bits(fetch_ofs_t)-1:0] = dst_ofs_out;
            DST_ACS_OUT[idst].data = dst_data_out[dst_ofs_out*$bits(SDRAM_PKG::data_t) +: $bits(SDRAM_PKG::data_t)];
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                dst_ofs_out <= 0;
                DST_WRITE_OUT[idst] <= 0;
                DST_REQ_OUT[idst] <= 0;
            end else if (!DST_REQ_OUT[idst]) begin
                // Start a new request
                dst_ofs_out <= 0;
                if (dst_fetch_req) begin
                    DST_WRITE_OUT[idst] <= 0;
                    DST_REQ_OUT[idst] <= 1;
                end else if (dst_write_req) begin
                    DST_WRITE_OUT[idst] <= 1;
                    DST_REQ_OUT[idst] <= 1;
                end
            end else if (DST_ACK_IN[idst]) begin
                // Continue current request
                dst_ofs_out <= dst_ofs_out + 1;
                DST_REQ_OUT[idst] <= dst_ofs_out != LINE_FETCHES-1;
            end
        end

    end: gen_dst
endgenerate

endmodule
