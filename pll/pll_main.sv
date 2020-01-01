// Main PLL
// Input clock frequency:
//  CLK_IN         50M
// Output clock frequencies:
//  CLK_OUT[0]  142.5M
//  CLK_OUT[1]  142.5M
//  CLK_OUT[2]     10M
//  CLK_OUT[3]     30M
//  CLK_OUT[4]    285M

module PLL_MAIN (
    input  wire        CLK_IN,
    input  logic       RESET,

    output wire  [4:0] CLK_OUT,
    output logic       LOCKED
);

PLL #(
    .N_CLK_IN   (1),
    .N_CLK_OUT  (5)
) pll (
    .CLK_IN     (CLK_IN),
    .RESET      (RESET),
    .CLK_OUT    (CLK_OUT),
    .LOCKED     (LOCKED)
);

endmodule
