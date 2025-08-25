module NES_PPU_RGB (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        PIXEL_VALID_IN,
    input  logic [5:0]  PIXEL_CLR_IN,
    output logic        PIXEL_VALID_OUT,
    output logic [23:0] PIXEL_RGB_OUT
);

typedef logic [23:0] rgb_t;
rgb_t lut [63:0];

// 2C02 RGB LUT from
// https://www.nesdev.org/wiki/PPU_palettes
assign lut['h00] = 'h626262;    // #626262
assign lut['h01] = 'h001c95;    // #001c95
assign lut['h02] = 'h1904ac;    // #1904ac
assign lut['h03] = 'h42009d;    // #42009d
assign lut['h04] = 'h61006b;    // #61006b
assign lut['h05] = 'h6e0025;    // #6e0025
assign lut['h06] = 'h650500;    // #650500
assign lut['h07] = 'h491e00;    // #491e00
assign lut['h08] = 'h223700;    // #223700
assign lut['h09] = 'h004900;    // #004900
assign lut['h0a] = 'h004f00;    // #004f00
assign lut['h0b] = 'h004816;    // #004816
assign lut['h0c] = 'h00355e;    // #00355e
assign lut['h0d] = 'h000000;    // #000000
assign lut['h0e] = 'h000000;    // #000000
assign lut['h0f] = 'h000000;    // #000000

assign lut['h10] = 'hababab;    // #ababab
assign lut['h11] = 'h0c4edb;    // #0c4edb
assign lut['h12] = 'h3d2eff;    // #3d2eff
assign lut['h13] = 'h7115f3;    // #7115f3
assign lut['h14] = 'h9b0bb9;    // #9b0bb9
assign lut['h15] = 'hb01262;    // #b01262
assign lut['h16] = 'ha92704;    // #a92704
assign lut['h17] = 'h894600;    // #894600
assign lut['h18] = 'h576600;    // #576600
assign lut['h19] = 'h237f00;    // #237f00
assign lut['h1a] = 'h008900;    // #008900
assign lut['h1b] = 'h008332;    // #008332
assign lut['h1c] = 'h006d90;    // #006d90
assign lut['h1d] = 'h000000;    // #000000
assign lut['h1e] = 'h000000;    // #000000
assign lut['h1f] = 'h000000;    // #000000

assign lut['h20] = 'hffffff;    // #ffffff
assign lut['h21] = 'h57a5ff;    // #57a5ff
assign lut['h22] = 'h8287ff;    // #8287ff
assign lut['h23] = 'hb46dff;    // #b46dff
assign lut['h24] = 'hdf60ff;    // #df60ff
assign lut['h25] = 'hf863c6;    // #f863c6
assign lut['h26] = 'hf8746d;    // #f8746d
assign lut['h27] = 'hde9020;    // #de9020
assign lut['h28] = 'hb3ae00;    // #b3ae00
assign lut['h29] = 'h81c800;    // #81c800
assign lut['h2a] = 'h56d522;    // #56d522
assign lut['h2b] = 'h3dd36f;    // #3dd36f
assign lut['h2c] = 'h3ec1c8;    // #3ec1c8
assign lut['h2d] = 'h4e4e4e;    // #4e4e4e
assign lut['h2e] = 'h000000;    // #000000
assign lut['h2f] = 'h000000;    // #000000

assign lut['h30] = 'hffffff;    // #ffffff
assign lut['h31] = 'hbee0ff;    // #bee0ff
assign lut['h32] = 'hcdd4ff;    // #cdd4ff
assign lut['h33] = 'he0caff;    // #e0caff
assign lut['h34] = 'hf1c4ff;    // #f1c4ff
assign lut['h35] = 'hfcc4ef;    // #fcc4ef
assign lut['h36] = 'hfdcace;    // #fdcace
assign lut['h37] = 'hf5d4af;    // #f5d4af
assign lut['h38] = 'he6df9c;    // #e6df9c
assign lut['h39] = 'hd3e99a;    // #d3e99a
assign lut['h3a] = 'hc2efa8;    // #c2efa8
assign lut['h3b] = 'hb7efc4;    // #b7efc4
assign lut['h3c] = 'hb6eae5;    // #b6eae5
assign lut['h3d] = 'hb8b8b8;    // #b8b8b8
assign lut['h3e] = 'h000000;    // #000000
assign lut['h3f] = 'h000000;    // #000000

always_ff @(posedge CLK, posedge RESET_IN) begin
    if (RESET_IN) begin
        PIXEL_VALID_OUT <= 0;
        PIXEL_RGB_OUT <= 0;
    end else begin
        PIXEL_VALID_OUT <= PIXEL_VALID_IN;
        if (PIXEL_VALID_IN)
            PIXEL_RGB_OUT <= lut[PIXEL_CLR_IN];
    end
end

endmodule
