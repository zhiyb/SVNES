`include "config.h"

module test_bootrom;

logic bus_oe;
logic [`BOOTROM_N - 1 : 0] bootrom_addr;
wire [`IDATA_N - 1 : 0] bus_idata;

bootrom r0 (.*);

initial
begin
	bus_oe = 1'b0;
	bootrom_addr = 'b0;
	
	#1us bus_oe = 1'b1;
	forever
		#1us bootrom_addr++;
	#1us bus_oe = 1'b0;
end

endmodule