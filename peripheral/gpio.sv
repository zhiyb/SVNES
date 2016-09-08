`include "defines.h"

module gpio (
	sys_if sys,
	input logic sel,
	periphbus_if pbus,
	// IO ports
	inout wire [7:0] io,
	output logic [7:0] iodir
);

/*** Internal registers ***/

logic [7:0] reg_dir, reg_in, reg_out;

/*** Register read & write ***/

logic we, oe;
assign we = sel & pbus.we;
assign oe = sel & ~pbus.we;

logic [7:0] periph_data;
assign pbus.data = oe ? periph_data : 8'bz;

always_comb
begin
	case (pbus.addr)
	`GPIO_DIR:	periph_data = reg_dir;
	`GPIO_OUT:	periph_data = reg_out;
	`GPIO_IN:	periph_data = reg_in;
	default:		periph_data = 8'h0;
	endcase
end

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		reg_dir <= 'b0;
		reg_out <= 'b0;
	end else if (we) begin
		case (pbus.addr)
		`GPIO_DIR:	reg_dir <= pbus.data;
		`GPIO_OUT:	reg_out <= pbus.data;
		endcase
	end

/*** Control logic ***/

assign reg_in = io;
assign iodir = reg_dir;

genvar i;
generate
	for (i = 0; i != 8; i++) begin: gen_io
		assign io[i] = reg_dir[i] ? reg_out[i] : 1'bz;
end
endgenerate

endmodule
