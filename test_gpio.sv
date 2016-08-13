`include "config.h"

module test_gpio;

logic clk, n_reset;
logic bus_we, bus_oe;
dataLogic test_data;
wire dataLogic bus_data;

assign bus_data = bus_we ? test_data : 'bz;

periphLogic periph_addr;
logic periph_sel;

wire dataLogic io;
gpio gpio0 (.*);

dataLogic test_io;
dataLogic test_oe;
genvar i;
generate
for (i = 0; i != `DATA_N; i++)
	assign io[i] = test_oe[i] ? test_io[i] : 'bz;
endgenerate

initial
begin
	n_reset = 1'b1;
	bus_we = 1'b0;
	bus_oe = 1'b0;
	test_data = 8'hff;
	test_oe = 8'h00;
	periph_sel = 'b0;
	periph_addr = `GPIO_OUT;
	#1us n_reset = 1'b0;
	#1us n_reset = 1'b1;
	#1us periph_sel = 'b1;
	
	#1us bus_we = 1'b1;
	
	#1us periph_addr = `GPIO_DIR;
	test_data = 8'hac;
	
	#1us bus_we = 1'b0;
	
	#1us bus_oe = 1'b1;
	test_oe = 8'h50;
	periph_addr = `GPIO_IN;
	
	#1us bus_oe = 1'b1;
	bus_we = 1'b0;
	periph_addr = 'b0;
	forever begin
		#2us periph_addr++;
	end
	#1us bus_oe = 1'b0;
end

initial
begin
	test_io = 'b0;
	forever #1us test_io++;
end

initial
begin
	clk = 1'b0;
	forever #500ns clk = ~clk;
end

endmodule
