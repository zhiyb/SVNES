module SDRAM #(
    parameter int AHB_PORTS     = 4,
    parameter int N_CMD_QUEUES  = AHB_PORTS,
    parameter int N_CACHE_LINES = 8,
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2, tRRD = 2,
                  tINIT = 14250, tREF = 1114,
                  CAS = 3, BURST = 8
) (
    input wire CLK,
    input wire RESET_IN,

    output logic INIT_DONE_OUT,

    // Upstream AHB ports
    input  AHB_PKG::addr_t  [AHB_PORTS-1:0] HADDR,
    input  AHB_PKG::burst_t [AHB_PORTS-1:0] HBURST,
    input  AHB_PKG::size_t  [AHB_PORTS-1:0] HSIZE,
    input  AHB_PKG::trans_t [AHB_PORTS-1:0] HTRANS,
    input  logic            [AHB_PORTS-1:0] HWRITE,
    input  AHB_PKG::data_t  [AHB_PORTS-1:0] HWDATA,
    output AHB_PKG::data_t  [AHB_PORTS-1:0] HRDATA,
    output logic            [AHB_PORTS-1:0] HREADY,
    output AHB_PKG::resp_t  [AHB_PORTS-1:0] HRESP,

    // Hardware interface
    inout  wire  [15:0] DRAM_DQ,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output wire         DRAM_CLK,
    output logic        DRAM_CKE,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

// AHB access -> SDRAM bursts
logic                    [AHB_PORTS-1:0] burst_write;
SDRAM_PKG::dram_access_t [AHB_PORTS-1:0] burst_acs;
logic                    [AHB_PORTS-1:0] burst_req;
logic                    [AHB_PORTS-1:0] burst_ack;
SDRAM_PKG::data_t        [AHB_PORTS-1:0] burst_write_data;
logic                    [AHB_PORTS-1:0] burst_valid;
SDRAM_PKG::data_t        [AHB_PORTS-1:0] burst_read_data;

generate
    genvar p;
    for (p = 0; p < AHB_PORTS; p++) begin: gen_port
        SDRAM_AHB #(
            .BURST (BURST)
        ) ahb (
            .CLK        (CLK),
            .RESET_IN   (RESET_IN),

            .HADDR          (HADDR[p]),
            .HBURST         (HBURST[p]),
            .HSIZE          (HSIZE[p]),
            .HTRANS         (HTRANS[p]),
            .HWRITE         (HWRITE[p]),
            .HWDATA         (HWDATA[p]),
            .HRDATA         (HRDATA[p]),
            .HREADY         (HREADY[p]),
            .HRESP          (HRESP[p]),

            // Downstream ports
            .WRITE_OUT      (burst_write[p]),
            .ACS_OUT        (burst_acs[p]),
            .REQ_OUT        (burst_req[p]),
            .ACK_IN         (burst_ack[p]),
            .WRITE_DATA_OUT (burst_write_data[p]),
            .VALID_IN       (burst_valid[p]),
            .READ_DATA_IN   (burst_read_data[p])
        );
    end: gen_port
endgenerate

// SDRAM bursts -> per-bank access
localparam N_BANKS = SDRAM_PKG::N_BANKS;
logic                    [N_BANKS-1:0] bank_write;
SDRAM_PKG::dram_access_t [N_BANKS-1:0] bank_acs;
logic                    [N_BANKS-1:0] bank_req;
logic                    [N_BANKS-1:0] bank_ack;
SDRAM_PKG::data_t        [N_BANKS-1:0] bank_write_data;

SDRAM_PKG::data_t read_data;
logic             read_valid;

SDRAM_AHB_ARB #(
    .AHB_PORTS (AHB_PORTS),
    .N_BANKS   (N_BANKS),
    .BURST     (BURST)
) ahb_arb (
    .CLK                  (CLK),
    .RESET_IN             (RESET_IN),

    .BURST_WRITE_IN      (burst_write),
    .BURST_ACS_IN        (burst_acs),
    .BURST_REQ_IN        (burst_req),
    .BURST_ACK_OUT       (burst_ack),
    .BURST_WRITE_DATA_IN (burst_write_data),
    .BURST_VALID_OUT     (burst_valid),
    .BURST_READ_DATA_OUT (burst_read_data),

    .BANK_WRITE_OUT      (bank_write),
    .BANK_ACS_OUT        (bank_acs),
    .BANK_REQ_OUT        (bank_req),
    .BANK_ACK_IN         (bank_ack),
    .BANK_WRITE_DATA_OUT (bank_write_data),

    .READ_DATA_IN        (read_data),
    .READ_VALID_IN       (read_valid)
);

// Per-bank access -> commands
SDRAM_PKG::cmd_t arb_cmd_data;

SDRAM_BANK_ARB #(
    .tRC   (tRC),
    .tRAS  (tRAS),
    .tRP   (tRP),
    .tRCD  (tRCD),
    .tMRD  (tMRD),
    .tDPL  (tDPL),
    .tQMD  (tQMD),
    .tRRD  (tRRD),
    .tINIT (tINIT),
    .tREF  (tREF),
    .CAS   (CAS),
    .BURST (BURST)
) bank_arb (
    .CLK                (CLK),
    .RESET_IN           (RESET_IN),
    .INIT_DONE_OUT      (INIT_DONE_OUT),

    .BANK_WRITE_IN      (bank_write),
    .BANK_ACS_IN        (bank_acs),
    .BANK_REQ_IN        (bank_req),
    .BANK_ACK_OUT       (bank_ack),
    .BANK_WRITE_DATA_IN (bank_write_data),

    .CMD_OUT            (arb_cmd_data)
);

// Execute commands
SDRAM_IO #(
    .tRC   (tRC),
    .tRAS  (tRAS),
    .tRP   (tRP),
    .tRCD  (tRCD),
    .tMRD  (tMRD),
    .tDPL  (tDPL),
    .tQMD  (tQMD),
    .tINIT (tINIT),
    .tREF  (tREF),
    .CAS   (CAS),
    .BURST (BURST)
) io (
    .CLK            (CLK),
    .RESET_IN       (RESET_IN),

    .CMD_IN         (arb_cmd_data),
    .READ_DATA_OUT  (read_data),
    .READ_VALID_OUT (read_valid),

    .DRAM_DQ        (DRAM_DQ),
    .DRAM_ADDR      (DRAM_ADDR),
    .DRAM_BA        (DRAM_BA),
    .DRAM_DQM       (DRAM_DQM),
    .DRAM_CLK       (DRAM_CLK),
    .DRAM_CKE       (DRAM_CKE),
    .DRAM_CS_N      (DRAM_CS_N),
    .DRAM_RAS_N     (DRAM_RAS_N),
    .DRAM_CAS_N     (DRAM_CAS_N),
    .DRAM_WE_N      (DRAM_WE_N)
);

endmodule
