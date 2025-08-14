module CDC_ASYNC #(
    parameter int WIDTH  = 1,
    parameter int STAGES = 2
) (
    input  wire              CLK,
    input  wire              RESET_IN,
    input  logic [WIDTH-1:0] DATA_IN,
    output logic [WIDTH-1:0] DATA_OUT
);

logic [STAGES-1:0][WIDTH-1:0] cdc_synchron;

always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        cdc_synchron <= ($bits(cdc_synchron))'(0);
    else
        cdc_synchron <= {cdc_synchron[STAGES-2:0], DATA_IN};

assign DATA_OUT = cdc_synchron[STAGES-1];

endmodule
