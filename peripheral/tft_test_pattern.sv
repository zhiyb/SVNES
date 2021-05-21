module TFT_TEST_PATTERN (
    input  wire  CLK,

    input  logic        HBLANK, VBLANK,
    output logic [23:0] COLOUR
);

logic z1_HBlank;
logic [9:0] x;
logic [8:0] y;

always_ff @(posedge CLK)
    z1_HBlank <= HBLANK;

always_ff @(posedge CLK)
    if (VBLANK)
        y <= 0;
    else if (~z1_HBlank & HBLANK)
        y <= y + 1;

always_ff @(posedge CLK)
    if (HBLANK)
        x <= 0;
    else
        x <= x + 1;

logic [7:0] r, g, b;
assign COLOUR = {r, g, b};

always_comb
begin
    //r = x[0] ^ y[0] ? 8'hff : 8'h00;
    r = {x[8 +: 2], 6'b0};
    g = x[7:0];
    b = y[7:0];
    if (x == 0)
        {r, g, b} = 24'hff0000;
    else if (x == 799)
        {r, g, b} = 24'h00ff00;
    if (y == 0)
        {r, g, b} = 24'h0000ff;
    else if (y == 479)
        {r, g, b} = 24'hffff00;
end

endmodule
