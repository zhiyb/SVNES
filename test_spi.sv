`include "config.h"

module test_spi;

logic clk, n_reset;
logic bus_we, bus_oe;
dataLogic test_data;
wire dataLogic bus_data;

logic test_oe;
assign test_oe = bus_we;
assign bus_data = test_oe ? test_data : 'bz;

periphLogic periph_addr;
logic periph_sel;

logic interrupt;
logic cs, miso, mosi, sck;
spi spi0 (.*);

initial
begin
	n_reset = 1'b1;
	bus_we = 1'b0;
	bus_oe = 1'b0;
	periph_sel = 'b0;
	periph_addr = `SPI_CTRL;
	test_data = `SPI_CTRL_CPOL | `SPI_CTRL_CPHA | 0;
	test_data = 0;
	cs = 1'b1;
	#1us n_reset = 1'b0;
	#1us n_reset = 1'b1;
	#1us periph_sel = 'b1;
	#1us bus_we = 1'b1;
	
	#2us periph_addr = `SPI_CTRL;
	test_data = test_data | `SPI_CTRL_EN;
	
	#1us cs = 1'b0;
	
	#1us periph_addr = `SPI_DATA;
	test_data = 'b10101100;
	
	#1us bus_we = 1'b0;
	
	#1us bus_oe = 1'b1;
	periph_addr = `SPI_STAT;
	
	for (;;)
		#1us if ((bus_data & `SPI_STAT_TXE) != 'b0)
			break;
	
	#1us periph_addr = `SPI_DATA;
	test_data = ~test_data;
	bus_oe = 1'b0;
	bus_we = 1'b1;
	
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
	miso = 1'b0;
	forever #2us miso = ~miso;
end

initial
begin
	clk = 1'b0;
	forever #500ns clk = ~clk;
end

endmodule
