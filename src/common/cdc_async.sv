module CDC_ASYNC #(
    parameter int WIDTH,
    parameter int STAGES = 2
) (
    input  wire              SRC_CLK,
    input  wire              SRC_RESET_IN,
    input  logic [WIDTH-1:0] SRC_DATA_IN,

    input  wire              DST_CLK,
    input  wire              DST_RESET_IN,
    output logic [WIDTH-1:0] DST_DATA_OUT
);

logic [STAGES-1:0][WIDTH-1:0] cdc_synchron;

always_ff @(posedge DST_CLK, posedge DST_RESET_IN)
    if (DST_RESET_IN)
        cdc_synchron <= ($bits(cdc_synchron))'(0);
    else
        cdc_synchron <= {cdc_synchron[STAGES-2:0], SRC_DATA_IN};

assign DST_DATA_OUT = cdc_synchron[STAGES-1];

endmodule
