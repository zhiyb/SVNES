module SDRAM_AHB #(
    parameter int BURST   = 8
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
    output logic                    WRITE_OUT,
    output SDRAM_PKG::dram_access_t ACS_OUT,
    output logic                    REQ_OUT,
    input  logic                    ACK_IN,
    output SDRAM_PKG::data_t        WRITE_DATA_OUT,
    input  logic                    VALID_IN,
    input  SDRAM_PKG::data_t        READ_DATA_IN
);

localparam BYTES_PER_BURST = BURST * $bits(SDRAM_PKG::data_t) / 8;
localparam MAX_BURSTS      = 16 * $bits(AHB_PKG::data_t) / $bits(SDRAM_PKG::data_t) / BURST;
localparam DATA_PER_AHB    = $bits(AHB_PKG::data_t) / $bits(SDRAM_PKG::data_t);
localparam AHB_PER_BURST   = $bits(SDRAM_PKG::data_t) * BURST / $bits(AHB_PKG::data_t);
localparam FIFO_DEPTH      = AHB_PER_BURST * 2;

// FIFO for SDRAM request queue
typedef struct packed {
    logic write;
    SDRAM_PKG::dram_access_t acs;
} req_t;

req_t req_fifo_write_data;
logic req_fifo_write_req;
req_t req_fifo_read_data;
logic req_fifo_read_req, req_fifo_read_ack;

FIFO_SYNC #(
    .WIDTH ($bits(req_t)),
    .DEPTH (MAX_BURSTS * 2)
) req_fifo (
    .CLK                (CLK),
    .RESET_IN           (RESET_IN),
    .WRITE_DATA_IN      (req_fifo_write_data),
    .WRITE_REQ_IN       (req_fifo_write_req),
    .WRITE_ACK_OUT      (),
    .WRITE_THRES_OUT    (),
    .READ_DATA_OUT      (req_fifo_read_data),
    .READ_REQ_OUT       (req_fifo_read_req),
    .READ_ACK_IN        (req_fifo_read_ack),
    .READ_THRES_OUT     ()
);

// FIFO for SDRAM data queue
AHB_PKG::data_t data_fifo_write_data;
logic data_fifo_write_req, data_fifo_write_thres;
AHB_PKG::data_t data_fifo_read_data;
logic data_fifo_read_req, data_fifo_read_ack, data_fifo_read_thres;

FIFO_SYNC #(
    .WIDTH           ($bits(AHB_PKG::data_t)),
    .DEPTH           (FIFO_DEPTH),
    .WRITE_THRESHOLD (AHB_PER_BURST),
    .READ_THRESHOLD  (AHB_PER_BURST)
) data_fifo (
    .CLK                (CLK),
    .RESET_IN           (RESET_IN),
    .WRITE_DATA_IN      (data_fifo_write_data),
    .WRITE_REQ_IN       (data_fifo_write_req),
    .WRITE_ACK_OUT      (),
    .WRITE_THRES_OUT    (data_fifo_write_thres),
    .READ_DATA_OUT      (data_fifo_read_data),
    .READ_REQ_OUT       (data_fifo_read_req),
    .READ_ACK_IN        (data_fifo_read_ack),
    .READ_THRES_OUT     (data_fifo_read_thres)
);

// Address phase

// Convert AHB access to SDRAM request
logic [$clog2(MAX_BURSTS)-1:0] num_bursts;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        num_bursts <= 0;
        req_fifo_write_req <= 0;
        req_fifo_write_data <= req_t'(0);
    end else begin
        req_fifo_write_req <= 0;
        if (HTRANS == AHB_PKG::TRANS_NONSEQ && HREADY) begin
            num_bursts <= (HBURST == AHB_PKG::BURST_INCR16 || HBURST == AHB_PKG::BURST_WRAP16 ? 16 / AHB_PER_BURST :
                           HBURST == AHB_PKG::BURST_INCR8  || HBURST == AHB_PKG::BURST_WRAP8  ?  8 / AHB_PER_BURST :
                           HBURST == AHB_PKG::BURST_INCR4  || HBURST == AHB_PKG::BURST_WRAP4  ?  4 / AHB_PER_BURST :
                           1) - 1;
            req_fifo_write_req <= 1;
            req_fifo_write_data.write <= HWRITE;
            {req_fifo_write_data.acs.bank, req_fifo_write_data.acs.row, req_fifo_write_data.acs.col} <=
                HADDR >> $clog2($bits(SDRAM_PKG::data_t)/8);
        end else if (num_bursts) begin
            num_bursts <= num_bursts - 1;
            req_fifo_write_req <= 1;
            req_fifo_write_data.acs.col <= req_fifo_write_data.acs.col + BURST;
        end
    end
end

// Accept AHB access based on FIFO level
logic [$clog2(FIFO_DEPTH+1)-1:0] write_fifo_level, read_fifo_level;
logic ahb_fifo_write;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        write_fifo_level <= 0;
    end else begin
        write_fifo_level <= write_fifo_level + (HREADY & ahb_fifo_write)
            - (write_fifo_level == 0 ? 0 : data_fifo_read_ack);
    end
end

logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_read;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        fifo_read <= 0;
    else if (VALID_IN)
        fifo_read <= 1;
    else if (HTRANS != AHB_PKG::TRANS_IDLE && HTRANS != AHB_PKG::TRANS_BUSY && HWRITE && HREADY)
        fifo_read <= 0;
end

AHB_PKG::data_t ahb_read_data;
logic ahb_read_buf, ahb_read_ack, ahb_read_req;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        ahb_read_buf <= 0;
    end else if (fifo_read) begin
        if (data_fifo_read_req & ahb_read_ack)
            ahb_read_buf <= ahb_read_req;
    end
end

assign ahb_read_ack = fifo_read & (~ahb_read_buf | ahb_read_req);

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        ahb_fifo_write <= 0;
        ahb_read_req <= 0;
        ahb_read_data <= 0;
        HREADY <= 1;
    end else begin
        if (!ahb_read_req && write_fifo_level < FIFO_DEPTH)
            HREADY <= 1;
        if (HREADY)
            ahb_fifo_write <= 0;
        if (data_fifo_read_req && ahb_read_ack) begin
            ahb_read_req <= 0;
            ahb_read_data <= data_fifo_read_data;
            HREADY <= 1;
        end
        if (HTRANS != AHB_PKG::TRANS_IDLE && HTRANS != AHB_PKG::TRANS_BUSY) begin
            if (HWRITE) begin
                if (HREADY)
                    ahb_fifo_write <= 1;
                HREADY <= write_fifo_level < FIFO_DEPTH;
            end else begin
                if (HREADY) begin
                    ahb_read_req <= 1;
                    if (data_fifo_read_req && ahb_read_ack)
                        ahb_read_data <= data_fifo_read_data;
                    HREADY <= data_fifo_read_req && ahb_read_ack;
                end
            end
        end
    end
end

assign HRESP = AHB_PKG::RESP_OKAY;

assign HRDATA = ahb_read_data;

logic read_valid;
AHB_PKG::data_t read_data;

always_comb begin
    data_fifo_write_data = 0;
    if (ahb_fifo_write)
        data_fifo_write_data |= HWDATA;
    if (read_valid)
        data_fifo_write_data |= {READ_DATA_IN, read_data} >> $bits(SDRAM_PKG::data_t);
end



// SDRAM access request
assign WRITE_OUT = req_fifo_read_data.write;
assign ACS_OUT   = req_fifo_read_data.acs;


logic [$clog2(BURST)-1:0] write_burst;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        write_burst <= 0;
    end else if (WRITE_OUT && ACK_IN) begin
        write_burst <= BURST - 1;
    end else if (write_burst != 0) begin
        write_burst <= write_burst - 1;
    end
end

logic [$clog2(DATA_PER_AHB)-1:0] write_seg;
assign write_seg = BURST - write_burst;

assign WRITE_DATA_OUT = data_fifo_read_data >> ($bits(SDRAM_PKG::data_t) * write_seg);

logic sdram_write_ack;
assign sdram_write_ack = &write_seg;


logic [$clog2(BURST)-1:0] read_burst;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        read_burst <= 0;
        read_data  <= 0;
    end else if (VALID_IN) begin
        read_burst <= BURST - 1;
        read_data  <= {READ_DATA_IN, read_data} >> $bits(SDRAM_PKG::data_t);
    end else if (read_burst != 0) begin
        read_burst <= read_burst - 1;
        read_data  <= {READ_DATA_IN, read_data} >> $bits(SDRAM_PKG::data_t);
    end
end

logic [$clog2(DATA_PER_AHB)-1:0] read_seg;
assign read_seg = BURST - read_burst;
assign read_valid = read_seg == DATA_PER_AHB - 1;

assign data_fifo_write_req = (HREADY && ahb_fifo_write) || read_valid;
assign data_fifo_read_ack = sdram_write_ack | ahb_read_ack;

always_comb begin
    REQ_OUT = req_fifo_read_req;
    if (WRITE_OUT) begin
        // Wait until there is enough data in FIFO
        if (!data_fifo_read_thres)
            REQ_OUT = 0;
    end else begin
        // Wait until there is enough spaces in FIFO
        if (!data_fifo_write_thres)
            REQ_OUT = 0;
    end
end

assign req_fifo_read_ack = ACK_IN;

endmodule
