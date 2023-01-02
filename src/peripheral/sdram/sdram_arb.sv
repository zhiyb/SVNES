module SDRAM_ARB #(
    parameter int NSRC = 4,
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2, tRRD = 2,
                  tINIT = 14250, tREF = 1114,
    parameter SDRAM_PKG::cas_t   CAS   = SDRAM_PKG::CAS_3,
    parameter SDRAM_PKG::burst_t BURST = SDRAM_PKG::BURST_8
) (
    input wire CLK,
    input wire RESET_IN,

    output logic INIT_DONE_OUT,

    // Upstream ports
    input  logic                    [NSRC-1:0] SRC_WRITE_IN,
    input  SDRAM_PKG::dram_access_t [NSRC-1:0] SRC_ACS_IN,
    output SDRAM_PKG::data_t        [NSRC-1:0] SRC_DATA_OUT,
    input  logic                    [NSRC-1:0] SRC_REQ_IN,
    output logic                    [NSRC-1:0] SRC_ACK_OUT,

    // Command interface
    output SDRAM_PKG::cmd_t CMD_DATA_OUT,
    output logic            CMD_REQ_OUT,
    input  logic            CMD_ACK_IN,

    // Read data input
    input  SDRAM_PKG::data_t READ_DATA_IN,
    input  SDRAM_PKG::tag_t  READ_TAG_IN
);

localparam tCAS   = SDRAM_PKG::N_CAS[CAS];
localparam tBURST = SDRAM_PKG::N_BURSTS[BURST];
localparam tRQL   = tCAS;

// Bank timers
typedef struct packed {
    logic [3:0]      t_pre;     // Time to precharge
    logic [3:0]      t_act;     // Time to row activation
    logic [3:0]      t_read;    // Time to read access
    logic [3:0]      t_write;   // Time to write access
    logic            b_act;     // Bank is active
    SDRAM_PKG::row_t b_row;     // Active row
} bank_t;

bank_t [SDRAM_PKG::N_BANKS-1:0] bank;

generate
    genvar ba;
    for (ba = 0; ba < SDRAM_PKG::N_BANKS; ba++) begin: gen_bank
        always_ff @(posedge CLK) begin
            if (bank[ba].t_pre != 0)
                bank[ba].t_pre <= bank[ba].t_pre - 1;
            if (bank[ba].t_act != 0)
                bank[ba].t_act <= bank[ba].t_act - 1;
            if (bank[ba].t_read != 0)
                bank[ba].t_read <= bank[ba].t_read - 1;
            if (bank[ba].t_write != 0)
                bank[ba].t_write <= bank[ba].t_write - 1;

            if (CMD_REQ_OUT & CMD_ACK_IN) begin
                if (CMD_DATA_OUT.op == SDRAM_PKG::OP_REF) begin
                    // Auto refresh (also used as partial reset)
                    bank[ba].t_act   <= tRC - 1;
                    bank[ba].t_read  <= 0;
                    bank[ba].t_write <= 0;
                    //bank[ba].b_act   <= 0;
                end else if (CMD_DATA_OUT.op == SDRAM_PKG::OP_PRE &&
                             (CMD_DATA_OUT.addr[SDRAM_PKG::PALL_BIT] ||
                              CMD_DATA_OUT.bank == ba)) begin
                    // Bank precharge
                    bank[ba].t_act   <= tRP - 1;
                    bank[ba].b_act   <= 0;
                end else if (CMD_DATA_OUT.op == SDRAM_PKG::OP_ACT &&
                             CMD_DATA_OUT.bank == ba) begin
                    // Same bank active
                    bank[ba].t_pre   <= tRAS - 1;
                    bank[ba].t_read  <= SDRAM_PKG::max(bank[ba].t_read,  tRCD - 1);
                    bank[ba].t_write <= SDRAM_PKG::max(bank[ba].t_write, tRCD - 1);
                    bank[ba].b_row   <= CMD_DATA_OUT.addr;
                    bank[ba].b_act   <= 1;
                end else if (CMD_DATA_OUT.op == SDRAM_PKG::OP_ACT) begin
                    // Different bank active
                    bank[ba].t_act   <= SDRAM_PKG::max(bank[ba].t_act,  tRRD - 1);
                end else if (CMD_DATA_OUT.op == SDRAM_PKG::OP_READ &&
                             CMD_DATA_OUT.bank == ba) begin
                    // Same bank read
                    bank[ba].t_pre   <= tCAS + tBURST - tRQL - 1;
                    bank[ba].t_read  <= tCAS + tBURST - tCAS - 1;
                    bank[ba].t_write <= tCAS + tBURST + 1 - 1;
                end else if (CMD_DATA_OUT.op == SDRAM_PKG::OP_READ) begin
                    // Different bank read
                    bank[ba].t_read  <= tCAS + tBURST - tCAS - 1;
                    bank[ba].t_write <= tCAS + tBURST + 1 - 1;
                end else if (CMD_DATA_OUT.op == SDRAM_PKG::OP_WRITE &&
                             CMD_DATA_OUT.bank == ba) begin
                    // Same bank write
                    bank[ba].t_pre   <= tBURST + tDPL - 1;
                    bank[ba].t_read  <= tBURST - 1;
                    bank[ba].t_write <= tBURST - 1;
                end else if (CMD_DATA_OUT.op == SDRAM_PKG::OP_WRITE) begin
                    // Different bank write
                    bank[ba].t_read  <= tBURST - 1;
                    bank[ba].t_write <= tBURST - 1;
                end
            end
        end
    end: gen_bank
endgenerate

// Pending burst counter
logic [$clog2(tBURST)-1:0] burst_cnt;
SDRAM_PKG::tag_t           burst_tag, burst_tag_sel;

always_ff @(posedge CLK)
    if (burst_cnt != 0)
        burst_cnt <= burst_cnt - 1;
    else if (CMD_REQ_OUT && CMD_ACK_IN &&
             (CMD_DATA_OUT.op == SDRAM_PKG::OP_WRITE ||
              CMD_DATA_OUT.op == SDRAM_PKG::OP_READ))
        burst_cnt <= tBURST - 1;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        burst_tag <= 0;
    else if (CMD_REQ_OUT && CMD_ACK_IN &&
             (CMD_DATA_OUT.op == SDRAM_PKG::OP_WRITE ||
              CMD_DATA_OUT.op == SDRAM_PKG::OP_READ))
        burst_tag <= burst_tag_sel;
    else if (burst_cnt == 1)
        burst_tag <= 0;

// Upstream port handler
SDRAM_PKG::data_t read_data;
always_ff @(posedge CLK)
    read_data <= READ_DATA_IN;

SDRAM_PKG::cmd_t [NSRC-1:0] src_cmd;
logic            [NSRC-1:0] src_req;
logic            [NSRC-1:0] src_ack;
logic            [NSRC-1:0] src_burst;

generate
    genvar src;
    for (src = 0; src < NSRC; src++) begin: gen_src
        always_comb begin
            bank_t ba;
            src_cmd[src] = '{default: 0};
            src_req[src] = 0;
            ba = SRC_ACS_IN[src].bank;
            src_cmd[src].bank = ba;
            src_cmd[src].addr = SRC_ACS_IN[src].col;
            src_cmd[src].data = 0;

            if (SRC_REQ_IN[src]) begin
                src_req[src] = 1;
                if (!bank[ba].b_act) begin
                    // Request bank active
                    src_cmd[src].op   = SDRAM_PKG::OP_ACT;
                    src_cmd[src].addr = SRC_ACS_IN[src].row;
                end else if (bank[ba].b_row != SRC_ACS_IN[src].row) begin
                    // Different row, request bank precharge
                    src_cmd[src].op   = SDRAM_PKG::OP_PRE;
                    src_cmd[src].addr[SDRAM_PKG::PALL_BIT] = 0;
                end else if (~SRC_WRITE_IN[src]) begin
                    // Read burst request
                    src_cmd[src].op   = SDRAM_PKG::OP_READ;
                    src_cmd[src].data = src + 1;
                end else begin
                    // Write burst request
                    src_cmd[src].op   = SDRAM_PKG::OP_WRITE;
                    src_cmd[src].data = SRC_ACS_IN[src].data;
                end
            end
        end

        logic [$clog2(tBURST+1)-1:0] read_burst_cnt;
        always_ff @(posedge CLK, posedge RESET_IN)
            if (RESET_IN)
                read_burst_cnt <= 0;
            else if (read_burst_cnt <= 1 && READ_TAG_IN == src + 1)
                read_burst_cnt <= tBURST;
            else if (read_burst_cnt != 0)
                read_burst_cnt <= read_burst_cnt - 1;

        assign SRC_DATA_OUT[src] = read_data;

        always_comb begin
            SRC_ACK_OUT[src] = 0;
            if (SRC_WRITE_IN[src])
                SRC_ACK_OUT[src] = CMD_REQ_OUT && CMD_ACK_IN &&
                                   src_cmd[src].op == SDRAM_PKG::OP_WRITE &&
                                   (burst_tag_sel == src + 1 || burst_tag == src + 1);
            if (read_burst_cnt != 0)
                SRC_ACK_OUT[src] = 1;
        end

        always_ff @(posedge CLK, posedge RESET_IN)
            if (RESET_IN)
                src_burst[src] <= 0;
            else if (burst_cnt <= 1 && SRC_WRITE_IN[src])
                src_burst[src] <= 0;
            else if (burst_cnt != 0 && burst_tag == src + 1)
                src_burst[src] <= 1;
            else if (read_burst_cnt <= 1)
                src_burst[src] <= 0;
    end: gen_src
endgenerate

// Special init/refresh opertions
SDRAM_PKG::cmd_t spc_cmd;
logic            spc_req;
logic            spc_ack;

logic bank_active;
always_comb begin
    int ba;
    bank_active = 0;
    for (ba = 0; ba < SDRAM_PKG::N_BANKS; ba++)
        bank_active |= bank[ba].b_act;
end

SDRAM_INIT #(
    .tRC        (tRC),
    .tRAS       (tRAS),
    .tRP        (tRP),
    .tRCD       (tRCD),
    .tMRD       (tMRD),
    .tDPL       (tDPL),
    .tQMD       (tQMD),
    .tINIT      (tINIT),
    .tREF       (tREF),
    .CAS        (CAS),
    .BURST      (BURST)
) spc (
    .CLK            (CLK),
    .RESET_IN       (RESET_IN),

    .INIT_DONE_OUT  (INIT_DONE_OUT),
    .BANK_ACTIVE_IN (bank_active),

    .CMD_DATA_OUT   (spc_cmd),
    .CMD_REQ_OUT    (spc_req),
    .CMD_ACK_IN     (spc_ack)
);

always_comb begin
    int ba;
    spc_ack = CMD_ACK_IN;
    if (spc_cmd.op == SDRAM_PKG::OP_PRE) begin
        for (ba = 0; ba < SDRAM_PKG::N_BANKS; ba++)
            if (bank[ba].t_pre != 0)
                spc_ack = 0;
    end else if (spc_cmd.op == SDRAM_PKG::OP_REF) begin
        for (ba = 0; ba < SDRAM_PKG::N_BANKS; ba++)
            if (bank[ba].t_act != 0)
                spc_ack = 0;
    end
end

// Output command arbiter
assign CMD_REQ_OUT = 1;
always_comb begin
    int src;
    CMD_DATA_OUT = src_cmd[0];
    CMD_DATA_OUT.op = SDRAM_PKG::OP_NOP;
    burst_tag_sel = 0;
    // Upstream port 0 has higher priority
    for (src = NSRC - 1; src >= 0; src--) begin
        if (src_req[src]) begin
            int ba;
            ba = src_cmd[src].bank;
            if (~src_burst[src] &&
                ((src_cmd[src].op == SDRAM_PKG::OP_ACT   && bank[ba].t_act == 0) ||
                 (src_cmd[src].op == SDRAM_PKG::OP_PRE   && bank[ba].t_pre == 0) ||
                 (src_cmd[src].op == SDRAM_PKG::OP_READ  && bank[ba].t_read == 0) ||
                 (src_cmd[src].op == SDRAM_PKG::OP_WRITE && bank[ba].t_write == 0)))
                burst_tag_sel = src + 1;
        end
    end
    // Init/refresh has highest priority
    if (spc_req) begin
        burst_tag_sel = 0;
        if (spc_ack)
            CMD_DATA_OUT = spc_cmd;
    end
    if (burst_tag_sel != 0)
        CMD_DATA_OUT = src_cmd[burst_tag_sel - 1];
    // Continue read/write pending burst data
    if (burst_cnt != 0)
        CMD_DATA_OUT.data = src_cmd[burst_tag - 1].data;
end

endmodule
