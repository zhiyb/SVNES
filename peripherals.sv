`include "config.h"

module peripherals (
	input logic clk, n_reset,
	input logic bus_we, bus_oe,
	input periphBusLogic periphbus_addr,
	inout wire dataLogic bus_data
);

periphLogic periph_addr;
assign periph_addr = periphbus_addr[`PERIPH_N - 1 : 0];

parameter MAP_N = `PERIPHBUS_N - `PERIPH_N;
logic [2 ** MAP_N - 1 : 0] periph_sel;
demux #(.N(MAP_N)) demux0 (
	.sel(periphbus_addr[`PERIPHBUS_N - 1 : `PERIPH_N]),
	.q(periph_sel)
);

logic interrupt;
logic cs, miso, mosi, sck;
spi spi0 (.periph_sel(periph_sel[0]), .*);

endmodule
