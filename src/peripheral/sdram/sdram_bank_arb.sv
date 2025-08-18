module SDRAM_BANK_ARB #(
    parameter N_BANKS = SDRAM_PKG::N_BANKS,
    // Timing parameters
    parameter tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
              tMRD = 2, tDPL = 2, tQMD = 2, tRRD = 2,
              tINIT = 14250, tREF = 1114,
              CAS = 3, BURST = 8
) (
    input wire CLK,
    input wire RESET_IN,

    output logic INIT_DONE_OUT,

    // Upstream per-bank ports
    input  logic                    [N_BANKS-1:0] BANK_WRITE_IN,
    input  SDRAM_PKG::dram_access_t [N_BANKS-1:0] BANK_ACS_IN,
    input  logic                    [N_BANKS-1:0] BANK_REQ_IN,
    output logic                    [N_BANKS-1:0] BANK_ACK_OUT,
    input  SDRAM_PKG::data_t        [N_BANKS-1:0] BANK_WRITE_DATA_IN,

    // Command output
    output SDRAM_PKG::cmd_t CMD_OUT
);

// Arbitrartion clock cycles:
// 1. Raise per-bank requests
// 2. Grant arbitration to a bank
// 3. Generate command, update timers and requests

logic [N_BANKS:0] grant;

// Initialisation and refresh controller
localparam logic [2:0] MRS_BURST[0:8] = '{0, 0, 1, 1, 2, 2, 2, 2, 3};
localparam logic [2:0] MRS_CAS[0:3]   = '{0, 1, 2, 3};
localparam logic [14:0] MRS = {5'b0, 1'b0, 2'b0, MRS_CAS[CAS], 1'b0, MRS_BURST[BURST]};

localparam tINIT_TOTAL = tINIT + tRP + tRC + tRC + tMRD;
localparam COUNT = tREF >= tINIT_TOTAL ? tREF : tINIT_TOTAL;
logic [$clog2(COUNT)-1:0] ref_cnt;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        ref_cnt <= tINIT_TOTAL - 1;
    else if (ref_cnt == 0)
        ref_cnt <= tREF - 1;
    else
        ref_cnt <= ref_cnt - 1;
end

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        INIT_DONE_OUT <= 0;
    else if (ref_cnt == 0)
        INIT_DONE_OUT <= 1;
end

enum {REF_IDLE,
    REF_NOP,    // Wait for timer state update
    REF_PRE,    // Send precharge all command
    REF_REF     // Send refresh command
} ref_state;
logic [3:0] ref_state_cnt;
logic ref_req, ref_ack;

logic bank_active;
logic t_pre_stall;
logic t_act_stall;

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        ref_state <= REF_IDLE;
        ref_state_cnt <= 0;
    end else if (INIT_DONE_OUT && ref_cnt == 0) begin
        ref_state <= REF_NOP;
        ref_state_cnt <= 0;
    end else if (ref_req && ref_state != REF_IDLE) begin
        if (ref_state == REF_NOP) begin
            if (grant[N_BANKS]) begin
                if (bank_active) begin
                    // Need to precharge all
                    if (!t_pre_stall)
                        ref_state <= REF_PRE;
                end else begin
                    // Skip precharging
                    if (!t_act_stall)
                        ref_state <= REF_REF;
                end
            end
        end else if (ref_state == REF_PRE) begin
            ref_state_cnt <= ref_state_cnt + 1;
            if (ref_state_cnt == tRP - 1) begin
                ref_state_cnt <= 0;
                ref_state <= REF_REF;
            end
        end else if (ref_state == REF_REF) begin
            ref_state_cnt <= ref_state_cnt + 1;
            // One cycle earlier to start data access arbitration quicker
            if (ref_state_cnt == tRC - 1 - 1) begin
                ref_state <= REF_IDLE;
            end
        end
    end
end

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        ref_req <= 1;
    else if (!INIT_DONE_OUT)
        ref_req <= ref_cnt != 0;
    else
        ref_req <= ref_state != REF_IDLE;
end

localparam REF_INIT_LATENCY = 0;
SDRAM_PKG::cmd_t ref_cmd_in;
always_comb begin
    ref_cmd_in = SDRAM_PKG::cmd_t'(0);
    if (!INIT_DONE_OUT) begin
        if (ref_cnt == REF_INIT_LATENCY + tMRD - 1) begin
            ref_cmd_in.op   |= SDRAM_PKG::OP_MRS;
            ref_cmd_in.data |= MRS;
        end else if (ref_cnt == REF_INIT_LATENCY + tMRD + tRC - 1) begin
            ref_cmd_in.op   |= SDRAM_PKG::OP_REF;
        end else if (ref_cnt == REF_INIT_LATENCY + tMRD + tRC + tRC - 1) begin
            ref_cmd_in.op   |= SDRAM_PKG::OP_REF;
        end else if (ref_cnt == REF_INIT_LATENCY + tMRD + tRC + tRC + tRP - 1) begin
            ref_cmd_in.op   |= SDRAM_PKG::OP_PRE;
            ref_cmd_in.addr[SDRAM_PKG::PALL_BIT] |= 1;
        end
    end
    if (ref_state == REF_PRE && ref_state_cnt == 0) begin
        ref_cmd_in.op |= SDRAM_PKG::OP_PRE;
        ref_cmd_in.addr[SDRAM_PKG::PALL_BIT] |= 1;
    end
    if (ref_state == REF_REF && ref_state_cnt == 0) begin
        ref_cmd_in.op |= SDRAM_PKG::OP_REF;
    end
end

SDRAM_PKG::cmd_t ref_cmd;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        ref_cmd <= SDRAM_PKG::cmd_t'(0);
    else
        ref_cmd <= ref_cmd_in;
end

// Bank timers
typedef struct packed {
    logic           t_pre_stall;
    logic           t_act_stall;
    logic           b_act;  // Bank is active
    logic           req;
    SDRAM_PKG::op_t op;
} bank_t;

bank_t [N_BANKS-1:0] bank;
SDRAM_PKG::cmd_t arb_cmd;

localparam tRQL = CAS;

logic [3:0] t_read;    // Time to read access
logic [3:0] t_write;   // Time to write access

generate
    genvar ba;
    for (ba = 0; ba < N_BANKS; ba++) begin: gen_bank
        logic [3:0] t_pre;          // Time to precharge
        logic [3:0] t_act;          // Time to row activation
        SDRAM_PKG::row_t b_row;     // Active row

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                t_pre          <= 0;
                t_act          <= 0;
                bank[ba].b_act <= 0;
            end else begin
                if (t_pre != 0)
                    t_pre <= t_pre - 1;
                if (t_act != 0)
                    t_act <= t_act - 1;

                // Update timers
                if (grant[ba]) begin
                    // Same bank events
                    if (bank[ba].op == SDRAM_PKG::OP_ACT) begin
                        t_pre   <= tRAS - 3;
                        b_row   <= BANK_ACS_IN[ba].row;
                        bank[ba].b_act <= 1;
                    end else if (bank[ba].op == SDRAM_PKG::OP_PRE) begin
                        t_act   <= tRP - 3;
                        bank[ba].b_act <= 0;
                    end else if (bank[ba].op == SDRAM_PKG::OP_READ) begin
                        t_pre   <= CAS + BURST - tRQL - 3;
                    end else if (bank[ba].op == SDRAM_PKG::OP_WRITE) begin
                        t_pre   <= BURST + tDPL - 3;
                    end
                end
                if (ref_state == REF_PRE) begin
                    bank[ba].b_act <= 0;
                end
            end
        end

        assign bank[ba].t_pre_stall = t_pre != 0;
        assign bank[ba].t_act_stall = t_act != 0;

        // Raise per-bank requests
        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN) begin
                bank[ba].req <= 0;
                bank[ba].op  <= SDRAM_PKG::OP_NOP;
            end else if (!BANK_REQ_IN[ba] || !INIT_DONE_OUT) begin
                // Input is idle, no request
                bank[ba].req <= 0;
                bank[ba].op  <= SDRAM_PKG::OP_NOP;
            end else if (grant[ba]) begin
                // Because of feedback latency, we can only send commands every 3 cycles
                bank[ba].req <= 0;
                bank[ba].op  <= SDRAM_PKG::OP_NOP;
            end else if (!bank[ba].b_act) begin
                // Bank is not active, request active
                bank[ba].req <= t_act == 0;
                bank[ba].op  <= SDRAM_PKG::OP_ACT;
            end else if (b_row != BANK_ACS_IN[ba].row) begin
                // Bank is active, but different row is opened, request precharge
                bank[ba].req <= t_pre == 0;
                bank[ba].op  <= SDRAM_PKG::OP_PRE;
            end else begin
                // Bank is active and correct row, request read/write access
                bank[ba].req <= 1;
                bank[ba].op  <= BANK_WRITE_IN[ba] ? SDRAM_PKG::OP_WRITE : SDRAM_PKG::OP_READ;
            end
        end

        always_ff @(posedge CLK, posedge RESET_IN) begin
            if (RESET_IN)
                BANK_ACK_OUT[ba] <= 0;
            else if (grant[ba] && (bank[ba].op == SDRAM_PKG::OP_READ || bank[ba].op == SDRAM_PKG::OP_WRITE))
                BANK_ACK_OUT[ba] <= 1;
            else
                BANK_ACK_OUT[ba] <= 0;
        end
    end: gen_bank
endgenerate

always_comb begin
    int ba;
    t_pre_stall = 0;
    t_act_stall = 0;
    bank_active = 0;
    for (ba = 0; ba < N_BANKS; ba++) begin
        t_pre_stall |= bank[ba].t_pre_stall;
        t_act_stall |= bank[ba].t_act_stall;
        bank_active |= bank[ba].b_act;
    end
end

// Timer between different banks
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        t_read <= 0;
        t_write <= 0;
    end else begin
        if (t_read != 0)
            t_read <= t_read - 1;
        if (t_write != 0)
            t_write <= t_write - 1;

        if (arb_cmd.op == SDRAM_PKG::OP_READ) begin
            t_read  <= CAS + BURST - CAS - 2;
            t_write <= CAS + BURST + 1 - 2;
        end else if (arb_cmd.op == SDRAM_PKG::OP_WRITE) begin
            t_read  <= BURST - 2;
            t_write <= BURST - 2;
        end
    end
end

// Grant arbitration to a bank
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        grant <= 0;
    end else begin
        int ba;
        grant <= 0;
        for (ba = 0; ba < N_BANKS; ba++) begin
            // All commands have wait states
            if (bank[ba].req && !grant[ba] &&
                // tRRD == 2
                !(bank[ba].op == SDRAM_PKG::OP_ACT && arb_cmd.op == SDRAM_PKG::OP_ACT) &&
                // tREAD/tWRITE > 2
                !((bank[ba].op == SDRAM_PKG::OP_READ || bank[ba].op == SDRAM_PKG::OP_WRITE) &&
                  (arb_cmd.op  == SDRAM_PKG::OP_READ || arb_cmd.op  == SDRAM_PKG::OP_WRITE)) &&
                // Check tREAD/tWRITE
                !(bank[ba].op == SDRAM_PKG::OP_READ && t_read != 0) &&
                !(bank[ba].op == SDRAM_PKG::OP_WRITE && t_write != 0)) begin
                grant <= 1 << ba;
                break;      // Bank 0 has highest prority
            end
        end
        if (ref_req)
            grant <= 1 << N_BANKS;
    end
end

// Generate command
always_comb begin
    int ba;
    arb_cmd = SDRAM_PKG::cmd_t'(0);
    for (ba = 0; ba < N_BANKS; ba++) begin
        if (grant[ba]) begin
            arb_cmd.op   |= bank[ba].op;
            arb_cmd.bank |= ba;
            if (bank[ba].op == SDRAM_PKG::OP_ACT) begin
                arb_cmd.addr |= BANK_ACS_IN[ba].row;
            end else if (bank[ba].op == SDRAM_PKG::OP_PRE) begin
                arb_cmd.addr[SDRAM_PKG::PALL_BIT] |= 0;
            end else if (bank[ba].op == SDRAM_PKG::OP_READ) begin
                arb_cmd.addr |= BANK_ACS_IN[ba].col;
                arb_cmd.data |= ba + 1;
            end else if (bank[ba].op == SDRAM_PKG::OP_WRITE) begin
                arb_cmd.addr |= BANK_ACS_IN[ba].col;
                arb_cmd.data |= BANK_WRITE_DATA_IN[ba];
            end
        end
    end
    if (grant[N_BANKS])
        arb_cmd |= ref_cmd;
end

SDRAM_PKG::cmd_t cmd;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        cmd <= SDRAM_PKG::cmd_t'(0);
    else
        cmd <= arb_cmd;
end

SDRAM_PKG::ba_t data_bank;
always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN)
        data_bank <= 0;
    else if (cmd.op == SDRAM_PKG::OP_WRITE)
        data_bank <= cmd.bank;
end

always_comb begin
    CMD_OUT = cmd;
    if (cmd.op != SDRAM_PKG::OP_WRITE && cmd.op != SDRAM_PKG::OP_MRS)
        CMD_OUT.data = BANK_WRITE_DATA_IN[data_bank];
end

endmodule
