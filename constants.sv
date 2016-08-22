`include "config.h"
import typepkg::*;

module constants (
	input logic oe,
	input Constants sel,
	output wire [`DATA_N - 1:0] out
);

dataLogic con;
assign out = oe ? con : {`DATA_N{1'bz}};

always_comb
begin
	case (sel)
	Con1:		con = 'h1;
	default:	con = 'h0;
	endcase
end

endmodule
