module SDRAM_IO
#(
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2,
                  tINIT = 14250, tREF = 1114,
    parameter SDRAM_PKG::cas_t   CAS   = SDRAM_PKG::CAS_3,
    parameter SDRAM_PKG::burst_t BURST = SDRAM_PKG::BURST_8
) (
    input wire CLK,
    input wire CLK_IO,
    input wire RESET_IN,

    // Command interface
    input  SDRAM_PKG::cmd_t CMD_DATA_IN,
    input  logic            CMD_REQ_IN,
    output logic            CMD_ACK_OUT,

    // Read data output
    output SDRAM_PKG::data_t READ_DATA_OUT,
    output SDRAM_PKG::tag_t  READ_TAG_OUT,

    // Hardware interface
    inout  wire  [15:0] DRAM_DQ,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA, DRAM_DQM,
    output wire         DRAM_CLK,
    output logic        DRAM_CKE,
    output logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);

// Pin input/output registers

logic [15:0] dram_dq_in;
logic [15:0] dram_dq,    dram_dq_out;
logic        dram_dq_en, dram_dq_out_en;
logic [12:0] dram_addr;
logic [1:0]  dram_ba, dram_dqm;
logic        dram_cke;
logic        dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n;

always_ff @(posedge CLK) begin
    dram_dq_in     <= DRAM_DQ;
    dram_dq_out    <= dram_dq;
    dram_dq_out_en <= dram_dq_en;
    DRAM_ADDR      <= dram_addr;
    DRAM_BA        <= dram_ba;
    DRAM_DQM       <= dram_dqm;
    DRAM_CKE       <= dram_cke;
    DRAM_CS_N      <= dram_cs_n;
    DRAM_RAS_N     <= dram_ras_n;
    DRAM_CAS_N     <= dram_cas_n;
    DRAM_WE_N      <= dram_we_n;
end

assign DRAM_DQ  = dram_dq_out_en ? dram_dq_out : 'z;
assign DRAM_CLK = CLK_IO;

// Read output pipe

localparam tCAS   = SDRAM_PKG::N_CAS[CAS];
localparam tBURST = SDRAM_PKG::N_BURSTS[BURST];
localparam READ_LATENCY = tCAS + tBURST + 2;

typedef struct packed {
    SDRAM_PKG::tag_t  tag;
    SDRAM_PKG::data_t data;
} read_data_t;

read_data_t read_pipe_in, read_pipe_out;
read_data_t [READ_LATENCY-1:0] read_pipe;

always_ff @(posedge CLK)
    read_pipe <= {read_pipe[READ_LATENCY-2:0], read_pipe_in};

assign READ_TAG_OUT  = read_pipe_out.tag;
assign READ_DATA_OUT = read_pipe_out.data;

// Pin driver

always_comb begin
    dram_dq    = CMD_DATA_IN.data;
    dram_dq_en = 0;
    dram_addr  = CMD_DATA_IN.addr;
    dram_ba    = CMD_DATA_IN.bank;
    dram_dqm   = 0;
    dram_cke   = 1;
    dram_cs_n  = 0;
    dram_ras_n = 1;
    dram_cas_n = 1;
    dram_we_n  = 1;
    read_pipe_in = '{default: 0};
    read_pipe_in.tag  = CMD_DATA_IN.data;
    read_pipe_in.data = dram_dq_in;

    case (CMD_DATA_IN.op)
    SDRAM_PKG::OP_NOP: begin
    end
    SDRAM_PKG::OP_REF: begin
        dram_ras_n = 0;
        dram_cas_n = 0;
        dram_we_n  = 1;
    end
    SDRAM_PKG::OP_PRE: begin
        dram_ras_n = 0;
        dram_cas_n = 1;
        dram_we_n  = 0;
        dram_addr[SDRAM_PKG::PALL_BIT] = CMD_DATA_IN.addr[SDRAM_PKG::PALL_BIT];
    end
    SDRAM_PKG::OP_ACT: begin
        dram_ras_n = 0;
        dram_cas_n = 1;
        dram_we_n  = 1;
        dram_addr  = CMD_DATA_IN.addr;
    end
    SDRAM_PKG::OP_WRITE: begin
        dram_ras_n = 1;
        dram_cas_n = 0;
        dram_we_n  = 0;
        dram_addr  = CMD_DATA_IN.addr;
        dram_dq_en = 1;
    end
    SDRAM_PKG::OP_READ: begin
        dram_ras_n = 1;
        dram_cas_n = 0;
        dram_we_n  = 1;
        dram_addr  = CMD_DATA_IN.addr;
        dram_dq_en = 0;
    end
    SDRAM_PKG::OP_MRS: begin
        dram_ras_n = 0;
        dram_cas_n = 0;
        dram_we_n  = 0;
        {dram_ba[1:0], dram_addr[12:0]} = CMD_DATA_IN.data;
        read_pipe_in.tag = 0;
    end
    endcase
end

assign CMD_ACK_OUT = 1;

endmodule
