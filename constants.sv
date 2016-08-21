`include "config.h"
import typepkg::*;

module constants (
	input logic oe,
	input Constants sel,
	output wire [`DATA_N - 1:0] out
);

dataLogic con;
assign out = oe ? con : 'bz;

always_comb
begin
	con = 'h0;
	case (sel)
	Con1:	con = 'h1;
	endcase
end

endmodule
