module SDRAM_INIT #(
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2,
                  tINIT = 14250, tREF = 1114,
                  CAS = 3, BURST = 8
) (
    input wire CLK,
    input wire RESET_IN,

    output logic INIT_DONE_OUT,
    input  logic BANK_ACTIVE_IN,

    // Command interface
    output SDRAM_PKG::cmd_t CMD_DATA_OUT,
    output logic            CMD_REQ_OUT,
    input  logic            CMD_ACK_IN
);

// Special init/refresh opertions

localparam logic [2:0] MRS_BURST[0:8] = '{0, 0, 1, 1, 2, 2, 2, 2, 3};
localparam logic [2:0] MRS_CAS[0:3]   = '{0, 1, 2, 3};
localparam logic [14:0] MRS = {5'b0, 1'b0, 2'b0, MRS_CAS[CAS], 1'b0, MRS_BURST[BURST]};

localparam tINIT_TOTAL = tINIT + tRP + tRC + tRC + tMRD;
logic [$clog2(tINIT_TOTAL)-1:0] spc_cnt;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        spc_cnt <= tINIT_TOTAL - 1;
    else if (spc_cnt == 0)
        spc_cnt <= tREF - 1;
    else
        spc_cnt <= spc_cnt - 1;

logic spc_init_done;
assign INIT_DONE_OUT = spc_init_done;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        spc_init_done <= 0;
    else if (spc_cnt == 0)
        spc_init_done <= 1;

SDRAM_PKG::cmd_t spc_cmd;
logic            spc_req;
logic            spc_ack;

enum {REF_NOP, REF_PRE, REF_REF} spc_ref_state;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        spc_ref_state <= REF_NOP;
    else if (spc_init_done && spc_cnt == 0)
        spc_ref_state <= BANK_ACTIVE_IN ? REF_PRE : REF_REF;
    else if (spc_req && spc_ack)
        spc_ref_state <= spc_ref_state == REF_PRE ? REF_REF : REF_NOP;

always_comb begin
    spc_cmd = '{default: 0};
    spc_req = ~spc_init_done;
    if (~spc_init_done) begin
        if (spc_cnt == tMRD - 1) begin
            spc_cmd.op   = SDRAM_PKG::OP_MRS;
            spc_cmd.data = MRS;
        end else if (spc_cnt == tMRD + tRC - 1) begin
            spc_cmd.op   = SDRAM_PKG::OP_REF;
        end else if (spc_cnt == tMRD + tRC + tRC - 1) begin
            spc_cmd.op   = SDRAM_PKG::OP_REF;
        end else if (spc_cnt == tMRD + tRC + tRC + tRP - 1) begin
            spc_cmd.op   = SDRAM_PKG::OP_PRE;
            spc_cmd.addr[SDRAM_PKG::PALL_BIT] = 1;
        end
    end else begin
        spc_req = spc_ref_state != REF_NOP;
        if (spc_ref_state == REF_PRE) begin
            spc_cmd.op = SDRAM_PKG::OP_PRE;
            spc_cmd.addr[SDRAM_PKG::PALL_BIT] = 1;
        end else if (spc_ref_state == REF_REF) begin
            spc_cmd.op = SDRAM_PKG::OP_REF;
        end
    end
end

/*
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        spc_req <= 0;
    else if (~spc_init_done)
        spc_req <= 1;
    else if (spc_ref_state != REF_NOP)
        spc_req <= 1;
    else if (spc_cnt == 0)
        spc_req <= 0;
*/

assign CMD_DATA_OUT = spc_cmd;
assign CMD_REQ_OUT  = spc_req;
assign spc_ack      = CMD_ACK_IN;

endmodule
