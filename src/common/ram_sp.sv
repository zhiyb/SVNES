// Single-port RAM
module RAM_SP #(
    parameter WIDTH,
    parameter DEPTH,
    parameter string INIT = "",
    parameter AW = $clog2(DEPTH)
) (
    input  wire               CLK,
    input  wire               RESET_IN,
    input  logic              CLEAR_IN,
    input  logic [AW-1:0]     ADDR_IN,
    input  logic              READ_ENABLE_IN,
    output logic [WIDTH-1:0]  READ_DATA_OUT,
    input  logic              WRITE_ENABLE_IN,
    input  logic [WIDTH-1:0]  WRITE_DATA_IN
);

typedef logic [WIDTH-1:0] data_t;
(* ramstyle = "no_rw_check" *) data_t mem [DEPTH-1:0];

`ifdef SIMULATION
initial begin
    if (INIT != "")
        $readmemh({"output_files/", INIT, ".svhex"}, mem);
end
`endif

always_ff @(posedge CLK)
    if (CLEAR_IN)
        mem <= '{default: '0};
    else if (WRITE_ENABLE_IN)
        mem[ADDR_IN] <= WRITE_DATA_IN;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        READ_DATA_OUT <= 0;
    else if (CLEAR_IN)
        READ_DATA_OUT <= 0;
    else if (READ_ENABLE_IN)
        READ_DATA_OUT <= mem[ADDR_IN];

endmodule
