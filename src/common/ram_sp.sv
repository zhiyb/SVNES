// Single-port RAM
module RAM_SP #(
    parameter WIDTH,
    parameter DEPTH,
    parameter string INIT = "",
    parameter AW = $clog2(DEPTH)
) (
    input  wire               CLK,
    input  wire               RESET_IN,
    input  logic [AW-1:0]     ADDR_IN,
    input  logic              READ_ENABLE_IN,
    output logic [WIDTH-1:0]  READ_DATA_OUT,
    input  logic              WRITE_ENABLE_IN,
    input  logic [WIDTH-1:0]  WRITE_DATA_IN
);

`ifdef SIMULATION

typedef logic [WIDTH-1:0] data_t;
data_t mem [DEPTH-1:0];

initial begin
    if (INIT != "")
        $readmemh({"output_files/", INIT, ".svhex"}, mem);
end

always_ff @(posedge CLK)
    if (WRITE_ENABLE_IN)
        mem[ADDR_IN] <= WRITE_DATA_IN;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        READ_DATA_OUT <= 0;
    else if (READ_ENABLE_IN)
        READ_DATA_OUT <= mem[ADDR_IN];

`else

altsyncram	altsyncram_component (
            .address_a (ADDR_IN),
            .clock0 (CLK),
            .data_a (WRITE_DATA_IN),
            .rden_a (READ_ENABLE_IN),
            .wren_a (WRITE_ENABLE_IN),
            .q_a (READ_DATA_OUT),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .address_b (1'b1),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_b (1'b1),
            .eccstatus (),
            .q_b (),
            .rden_b (1'b1),
            .wren_b (1'b0));
defparam
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.init_file = {INIT, "/rom.hex"},
    altsyncram_component.intended_device_family = "Cyclone IV E",
    altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = DEPTH,
    altsyncram_component.operation_mode = "SINGLE_PORT",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_reg_a = "UNREGISTERED",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.read_during_write_mode_port_a = "DONT_CARE",
    altsyncram_component.widthad_a = AW,
    altsyncram_component.width_a = WIDTH,
    altsyncram_component.width_byteena_a = 1;

`endif

endmodule
