`include "config.h"

module test_peripherals;

logic clk, n_reset;
logic bus_we, bus_oe, periphs_sel;
logic [`DATA_N - 1 : 0] test_data;
wire [`DATA_N - 1 : 0] bus_data;

logic test_oe;
assign test_oe = bus_we;
assign bus_data = test_oe ? test_data : 'bz;

logic [`PERIPHS_N - 1 : 0] periphs_addr;

// GPIO
wire [`DATA_N - 1 : 0] io[2];
assign io[1] = ~io[0];
// SPI
logic cs, miso;
logic mosi, sck;
peripherals p0 (.*);

initial
begin
	n_reset = 1'b1;
	bus_we = 1'b0;
	bus_oe = 1'b0;
	periphs_sel = 1'b0;
	periphs_addr = `P_SPI0 | `SPI_CTRL;
	test_data = `SPI_CTRL_CPOL | `SPI_CTRL_CPHA | 0;
	test_data = 0;
	cs = 1'b1;
	#1us n_reset = 1'b0;
	#1us n_reset = 1'b1;
	#1us periphs_sel = 1'b1;
	#1us bus_we = 1'b1;
	
	#2us periphs_addr = `P_SPI0 | `SPI_CTRL;
	test_data = test_data | `SPI_CTRL_EN;
	
	#1us cs = 1'b0;
	
	#1us periphs_addr = `P_SPI0 | `SPI_DATA;
	test_data = 'b10101100;
	
	#1us bus_we = 1'b0;
	
	#1us bus_oe = 1'b1;
	periphs_addr = `P_SPI0 | `SPI_STAT;
	
	for (;;)
		#1us if ((bus_data & `SPI_STAT_TXE) != 'b0)
			break;
	
	#1us periphs_addr = `P_SPI0 | `SPI_DATA;
	test_data = ~test_data;
	bus_oe = 1'b0;
	bus_we = 1'b1;
	
	#1us periphs_addr = `P_GPIO0 | `GPIO_DIR;
	test_data = 8'hff;
	
	#1us periphs_addr = `P_GPIO0 | `GPIO_OUT;
	test_data = 8'hac;
	
	#1us bus_oe = 1'b1;
	bus_we = 1'b0;
	for (periphs_addr = 'b0; periphs_addr != `P_SPI0; periphs_addr++)
		#1us;
	forever begin
		for (periphs_addr = `P_SPI0; periphs_addr != `P_SPI0 + 2 ** `PERIPH_N; periphs_addr++)
			#1us;
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
