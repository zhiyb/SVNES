`include "config.h"

module gpio (
	// Peripheral clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe, periph_sel,
	input periphLogic periph_addr,
	inout dataLogic bus_data,
	// IO ports
	inout dataLogic io
);

/*** Internal registers ***/

dataLogic reg_dir, reg_in, reg_out;

/*** Register read & write ***/

logic we, oe;
assign we = periph_sel & bus_we;
assign oe = periph_sel & bus_oe;

dataLogic periph_data;
assign bus_data = oe ? periph_data : {`DATA_N{1'bz}};

always_comb
begin
	case (periph_addr)
	`GPIO_DIR:	periph_data = reg_dir;
	`GPIO_OUT:	periph_data = reg_out;
	`GPIO_IN:	periph_data = reg_in;
	default:		periph_data = {`DATA_N{1'b0}};
	endcase
end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		reg_dir <= 'b0;
		reg_out <= 'b0;
	end else if (we) begin
		case (periph_addr)
		`GPIO_DIR:	reg_dir <= bus_data;
		`GPIO_OUT:	reg_out <= bus_data;
		endcase
	end

/*** Control logic ***/

assign reg_in = io;

genvar i;
generate
for (i = 0; i != `DATA_N; i++) begin: gen_io
	assign io[i] = reg_dir[i] ? reg_out[i] : 1'bz;
end
endgenerate

endmodule
