module SIM_SDRAM #(
    parameter int N_ROW_BITS = 13,
    parameter int N_COL_BITS = 10,
    // Timing parameters
    parameter int tRC = 9, tRAS = 6, tRP = 3, tRCD = 3,
                  tMRD = 2, tDPL = 2, tQMD = 2, tRRD = 2,
                  tINIT = 14250, tREF = 1114,
                  CAS = 3, BURST = 8
) (
    inout wire  [15:0] DRAM_DQ,
    input logic [12:0] DRAM_ADDR,
    input logic [1:0]  DRAM_BA, DRAM_DQM,
    input wire         DRAM_CLK,
    input logic        DRAM_CKE,
    input logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
);


logic [15:0] mem [2**N_ROW_BITS-1:0][2**N_COL_BITS-1:0];

logic assert_disable;
logic RESET;
initial begin
    longint ir, ic, v;
    assert_disable = 1;
    RESET = 0;
    #1us RESET = 1;
    #1us RESET = 0;
    assert_disable = 0;
    v = 0;
    for (ir = 0; ir < 2**N_ROW_BITS; ir++) begin
        for (ic = 0; ic < 2**N_COL_BITS; ic++) begin
            mem[ir][ic] = ic[0] ? v[23:16] : v[15:0];
            v += ic[0];
        end
    end
end


typedef enum logic [2:0] {
    PRE   = 3'b010,
    ACT   = 3'b011,
    WRITE = 3'b100,
    READ  = 3'b101
} cmd_t;

cmd_t cmd;
assign cmd = cmd_t'({DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N});


logic [3:0][N_ROW_BITS-1:0] row;
always_ff @(posedge DRAM_CLK)
    if (cmd == PRE && DRAM_ADDR[10])
        row <= 'x;
    else if (cmd == PRE && !DRAM_ADDR[10])
        row[DRAM_BA] <= 'x;
    else if (cmd == ACT)
        row[DRAM_BA] <= DRAM_ADDR;


logic [BURST-1:0] write_pipe;
logic [15:0] write_data;
always_ff @(posedge DRAM_CLK) begin
    write_pipe <= {write_pipe, cmd == WRITE};
    write_data <= DRAM_DQ;
end

logic [N_ROW_BITS-1:0] write_row;
logic [N_COL_BITS-1:0] write_col;
always_ff @(posedge DRAM_CLK) begin
    if (cmd == WRITE) begin
        write_row <= row[DRAM_BA];
        write_col <= DRAM_ADDR;
    end else if (write_pipe[BURST-1]) begin
        write_row <= 'x;
        write_col <= 'x;
    end else if (write_pipe != 0) begin
        write_col <= write_col + 1;
    end
end

always_ff @(posedge DRAM_CLK)
    if (write_pipe != 0)
        mem[write_row][write_col] <= write_data;


localparam READ_LATENCY = CAS - 1;

logic [BURST-1:0] read_pipe;
logic [READ_LATENCY-1:0] read_pipe_cas;
logic [READ_LATENCY-1:0][N_ROW_BITS-1:0] read_row_cas;
logic [READ_LATENCY-1:0][N_COL_BITS-1:0] read_col_cas;
always_ff @(posedge DRAM_CLK) begin
    {read_pipe, read_pipe_cas} <= {read_pipe, read_pipe_cas, cmd == READ};
    read_row_cas <= {read_row_cas, N_ROW_BITS'(cmd == READ ? row[DRAM_BA] : 'x)};
    read_col_cas <= {read_col_cas, N_COL_BITS'(cmd == READ ? DRAM_ADDR : 'x)};
end

logic [N_ROW_BITS-1:0] read_row;
logic [N_COL_BITS-1:0] read_col;
always_ff @(posedge DRAM_CLK) begin
    if (read_pipe[BURST-2:0] != 0) begin
        read_col <= read_col + 1;
    end else begin
        read_row <= read_row_cas[READ_LATENCY-1];
        read_col <= read_col_cas[READ_LATENCY-1];
    end
end

logic read_valid;
assign read_valid = read_pipe != 0;

assign DRAM_DQ = read_valid ? mem[read_row][read_col] : 'z;


always_ff @(DRAM_CLK) begin
    assert (assert_disable || read_pipe == 0 || !$isunknown(DRAM_DQ)) else $error("Read data X");
    assert (assert_disable || write_pipe == 0 || !$isunknown(write_data)) else $error("Write data X");
end


endmodule
