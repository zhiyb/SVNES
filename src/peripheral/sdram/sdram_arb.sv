module SDRAM_ARB #(
    parameter int N_SRC = SDRAM_PKG::N_BANKS,
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2, tRRD = 2,
                  tINIT = 14250, tREF = 1114,
                  CAS = 3, BURST = 8
) (
    input wire CLK,
    input wire RESET_IN,

    output logic INIT_DONE_OUT,

    // Upstream ports
    input  logic                    [N_SRC-1:0] SRC_WRITE_IN,
    input  SDRAM_PKG::dram_access_t [N_SRC-1:0] SRC_ACS_IN,
    input  logic                    [N_SRC-1:0] SRC_RCHG_IN,
    output SDRAM_PKG::data_t        [N_SRC-1:0] SRC_DATA_OUT,
    input  logic                    [N_SRC-1:0] SRC_REQ_IN,
    output logic                    [N_SRC-1:0] SRC_ACK_OUT,

    // Command output
    output SDRAM_PKG::cmd_t CMD_OUT,
    // Read data input
    input  SDRAM_PKG::data_t READ_DATA_IN,
    input  SDRAM_PKG::tag_t  READ_TAG_IN
);

// Fixed bank per-port, N_SRC should equal to N_BANKS
localparam FIXED_BANK = 1;
// Use row-change input instead of tracking active bank row here
localparam USE_RCHG   = 1;

localparam tRQL = CAS;

// Bank timers
typedef struct packed {
    logic            t_pre_block;
    logic            t_act_block;
    logic            t_read_block;
    logic            t_write_block;
    logic            b_act;     // Bank is active
    SDRAM_PKG::row_t b_row;     // Active row
} bank_t;

bank_t [SDRAM_PKG::N_BANKS-1:0] bank;

SDRAM_PKG::cmd_t src_cmd_arb;
SDRAM_PKG::cmd_t spc_cmd;
SDRAM_PKG::cmd_t arb_cmd;

generate
    genvar ba;
    for (ba = 0; ba < SDRAM_PKG::N_BANKS; ba++) begin: gen_bank
        logic [3:0] t_pre;     // Time to precharge
        logic [3:0] t_act;     // Time to row activation
        logic [3:0] t_read;    // Time to read access
        logic [3:0] t_write;   // Time to write access

        logic bank_sel;
        assign bank_sel = src_cmd_arb.bank == ba;

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                t_pre                   <= 0;
                bank[ba].t_pre_block    <= 0;
                t_act                   <= 0;
                bank[ba].t_act_block    <= 0;
                t_read                  <= 0;
                bank[ba].t_read_block   <= 0;
                t_write                 <= 0;
                bank[ba].t_write_block  <= 0;
                bank[ba].b_act          <= 0;
                bank[ba].b_row          <= 0;
            end else begin
                if (t_pre != 0)
                    t_pre <= t_pre - 1;
                if (t_pre <= 1)
                    bank[ba].t_pre_block <= 0;
                if (t_act != 0)
                    t_act <= t_act - 1;
                if (t_act <= 1)
                    bank[ba].t_act_block <= 0;
                if (t_read != 0)
                    t_read <= t_read - 1;
                if (t_write != 0)
                    t_write <= t_write - 1;
                if (t_read <= 1)
                    bank[ba].t_read_block <= 0;
                if (t_write <= 1)
                    bank[ba].t_write_block <= 0;

                if (arb_cmd.op & SDRAM_PKG::OP_REF) begin
                    // Auto refresh
                    t_act                   <= tRC - 1;
                    bank[ba].t_act_block    <= 1;
                end
                if ((arb_cmd.op & SDRAM_PKG::OP_PRE) &&
                    (arb_cmd.addr[SDRAM_PKG::PALL_BIT] || bank_sel)) begin
                    // Bank precharge
                    t_act                   <= tRP - 1;
                    bank[ba].t_act_block    <= 1;
                    bank[ba].b_act          <= 0;
                end
                if ((src_cmd_arb.op & SDRAM_PKG::OP_ACT) && bank_sel) begin
                    // Same bank active
                    t_pre                   <= tRAS - 1;
                    bank[ba].t_pre_block    <= 1;
                    bank[ba].b_act          <= 1;
                    bank[ba].b_row          <= src_cmd_arb.addr;
                    t_read                  <= SDRAM_PKG::max(t_read,  tRCD - 1);
                    t_write                 <= SDRAM_PKG::max(t_write, tRCD - 1);
                    bank[ba].t_read_block   <= 1;
                    bank[ba].t_write_block  <= 1;
                end else if (src_cmd_arb.op & SDRAM_PKG::OP_ACT) begin
                    // Different bank active
                    t_act                   <= SDRAM_PKG::max(t_act,  tRRD - 1);
                    bank[ba].t_act_block    <= 1;
                end
                if (src_cmd_arb.op & SDRAM_PKG::OP_READ) begin
                    // Read
                    t_read                  <= CAS + BURST - CAS - 1;
                    t_write                 <= CAS + BURST + 1 - 1;
                    bank[ba].t_read_block   <= 1;
                    bank[ba].t_write_block  <= 1;
                end
                if ((src_cmd_arb.op & SDRAM_PKG::OP_READ) && bank_sel) begin
                    // Same bank read
                    t_pre                   <= CAS + BURST - tRQL - 1;
                    bank[ba].t_pre_block    <= 1;
                end
                if (src_cmd_arb.op & SDRAM_PKG::OP_WRITE) begin
                    // Write
                    t_read                  <= BURST - 1;
                    t_write                 <= BURST - 1;
                    bank[ba].t_read_block   <= 1;
                    bank[ba].t_write_block  <= 1;
                end
                if ((src_cmd_arb.op & SDRAM_PKG::OP_WRITE) && bank_sel) begin
                    // Same bank write
                    t_pre                   <= BURST + tDPL - 1;
                    bank[ba].t_pre_block    <= 1;
                end
            end
        end
    end: gen_bank
endgenerate

// Pending burst counter
logic [$clog2(BURST)-1:0] burst_cnt;
logic [N_SRC-1:0]         burst_src, cmd_src_sel;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        burst_cnt <= 0;
    else if (burst_cnt != 0)
        burst_cnt <= burst_cnt - 1;
    else if (src_cmd_arb.op & (SDRAM_PKG::OP_WRITE | SDRAM_PKG::OP_READ))
        burst_cnt <= BURST - 1;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        burst_src <= 0;
    else if (src_cmd_arb.op & (SDRAM_PKG::OP_WRITE | SDRAM_PKG::OP_READ))
        burst_src <= cmd_src_sel;
    else if (burst_cnt == 1)
        burst_src <= 0;

// Upstream port handler
SDRAM_PKG::cmd_t [N_SRC-1:0] src_cmd;
logic            [N_SRC-1:0] src_req;
logic            [N_SRC-1:0] src_burst;

SDRAM_PKG::data_t read_data;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        read_data <= 0;
    else
        read_data <= READ_DATA_IN;

generate
    genvar src;
    for (src = 0; src < N_SRC; src++) begin: gen_src
        logic row_change;

        always_comb begin
            bank_t ba;
            src_req[src] = 0;
            src_cmd[src] = '{default: 0};
            src_cmd[src].bank = FIXED_BANK ? src : SRC_ACS_IN[src].bank;
            src_cmd[src].addr = SRC_ACS_IN[src].col;
            src_cmd[src].data = 0;

            ba = FIXED_BANK ? src : SRC_ACS_IN[src].bank;
            if (!bank[ba].b_act) begin
                // Request bank active
                src_req[src]      = ~bank[ba].t_act_block;
                src_cmd[src].op   = SDRAM_PKG::OP_ACT;
                src_cmd[src].addr = SRC_ACS_IN[src].row;
            end else if (FIXED_BANK && USE_RCHG ?
                         ~row_change && SRC_RCHG_IN[src] :
                         bank[ba].b_row != SRC_ACS_IN[src].row) begin
                // Different row, request bank precharge
                src_req[src]      = ~bank[ba].t_pre_block;
                src_cmd[src].op   = SDRAM_PKG::OP_PRE;
                src_cmd[src].addr[SDRAM_PKG::PALL_BIT] = 0;
            end else if (~SRC_WRITE_IN[src]) begin
                // Read burst request
                src_req[src]      = ~bank[ba].t_read_block;
                src_cmd[src].op   = SDRAM_PKG::OP_READ;
                src_cmd[src].data = src + 1;
            end else begin
                // Write burst request
                src_req[src]      = ~bank[ba].t_write_block;
                src_cmd[src].op   = SDRAM_PKG::OP_WRITE;
                src_cmd[src].data = SRC_ACS_IN[src].data;
            end

            // Burst is in progress
            if (src_burst[src])
                src_req[src] = 0;
            // SRC isn't actually active
            if (~SRC_REQ_IN[src])
                src_req[src] = 0;

        end

        logic [$clog2(BURST+1)-1:0] read_burst_cnt;
        always_ff @(posedge CLK, posedge RESET_IN)
            if (RESET_IN)
                read_burst_cnt <= 0;
            else if (read_burst_cnt <= 1 && READ_TAG_IN == src + 1)
                read_burst_cnt <= BURST;
            else if (read_burst_cnt != 0)
                read_burst_cnt <= read_burst_cnt - 1;

        always_ff @(posedge CLK, posedge RESET_IN)
            if (RESET_IN)
                row_change <= 0;
            else if (cmd_src_sel[src])
                row_change <= SRC_RCHG_IN[src];
            else if (src_burst[src]) begin
                // Clear row_change after last beat in burst
                if (SRC_WRITE_IN[src] && burst_cnt <= 1)
                    row_change <= 0;
                else if (~SRC_WRITE_IN[src] && read_burst_cnt <= 1)
                    row_change <= 0;
            end

        assign SRC_DATA_OUT[src] = read_data;

        always_comb begin
            SRC_ACK_OUT[src] = 0;
            if (SRC_WRITE_IN[src])
                SRC_ACK_OUT[src] = (src_cmd[src].op & SDRAM_PKG::OP_WRITE) &&
                                   (cmd_src_sel[src] | burst_src[src]);
            if (read_burst_cnt != 0)
                SRC_ACK_OUT[src] = 1;
        end

        always_ff @(posedge CLK, posedge RESET_IN)
            if (RESET_IN)
                src_burst[src] <= 0;
            else if (burst_cnt <= 1 && SRC_WRITE_IN[src])
                src_burst[src] <= 0;
            else if (burst_cnt != 0 && burst_src[src])
                src_burst[src] <= 1;
            else if (read_burst_cnt <= 1)
                src_burst[src] <= 0;
    end: gen_src
endgenerate

// Special init/refresh opertions
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
    spc_ack = 1;
    if (spc_cmd.op & SDRAM_PKG::OP_PRE) begin
        for (ba = 0; ba < SDRAM_PKG::N_BANKS; ba++)
            if (bank[ba].t_pre_block)
                spc_ack = 0;
    end else if (spc_cmd.op & SDRAM_PKG::OP_REF) begin
        for (ba = 0; ba < SDRAM_PKG::N_BANKS; ba++)
            if (bank[ba].t_act_block)
                spc_ack = 0;
    end
end

// Output command arbiter
always_comb begin
    int i;
    cmd_src_sel = 0;
    // Upstream port 0 has higher priority
    for (i = 0; i < N_SRC; i++) begin
        if (src_req[i]) begin
            cmd_src_sel[i] = 1;
            break;
        end
    end
    // Init/refresh has highest priority
    if (spc_req)
        cmd_src_sel = 0;
end

always_comb begin
    int src;
    src_cmd_arb = '{default: 0};
    // Command ports
    for (src = 0; src < N_SRC; src++) begin
        if (cmd_src_sel[src])
            src_cmd_arb |= src_cmd[src];
        // Continue read/write pending burst data
        if (burst_src[src])
            src_cmd_arb.data |= src_cmd[src].data;
    end
end

always_comb begin
    arb_cmd = src_cmd_arb;
    // Init/refresh has highest priority
    if (spc_ack)
        arb_cmd |= spc_cmd;
end

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        CMD_OUT <= '{default: 0};
    else
        CMD_OUT <= arb_cmd;

endmodule
