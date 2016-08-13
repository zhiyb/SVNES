`include "config.h"

module spi (
	// Peripheral clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe, periph_sel,
	input periphLogic periph_addr,
	inout dataLogic bus_data,
	// Interrupt
	output logic interrupt,
	// IO ports
	input logic cs, miso,
	output logic mosi, sck
);

/*** Internal registers ***/

dataLogic reg_ctrl, reg_stat, reg_data[2];

/*** Register read & write ***/

logic we, oe;
assign we = periph_sel & bus_we;
assign oe = periph_sel & bus_oe;

dataLogic periph_data;
assign bus_data = oe ? periph_data : {`DATA_N{1'bz}};

always_comb
begin
	case (periph_addr)
	`SPI_CTRL:	periph_data = reg_ctrl & `SPI_CTRL_MASK;
	`SPI_STAT:	periph_data = reg_stat & `SPI_STAT_MASK;
	`SPI_DATA:	periph_data = reg_data[`RX];
	default:		periph_data = {`DATA_N{1'b0}};
	endcase
end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		reg_ctrl <= `DATA_N'b0;
		reg_data[`TX] <= `DATA_N'b0;
	end else if (we) begin
		case (periph_addr)
		`SPI_CTRL:	reg_ctrl <= bus_data;
		`SPI_DATA:	reg_data[`TX] <= bus_data;
		endcase
	end

/*** Control signals ***/

logic enabled, cpha, cpol;
assign enabled = (reg_ctrl & `SPI_CTRL_EN) != 'b0;
assign cpha = (reg_ctrl & `SPI_CTRL_CPHA) != 'b0;
assign cpol = (reg_ctrl & `SPI_CTRL_CPOL) != 'b0;

logic [2 : 0] pr_sel;
assign pr_sel = reg_ctrl[2:0];

/*** Clock prescaler ***/

parameter PR_N = 8;
logic n_sh_reset;
logic [PR_N : 0] pr_clk;
prescaler #(.n(PR_N)) p0 (.n_reset(n_reset && n_sh_reset), .clk(clk), .counter(pr_clk));

logic sclk, spiclk;
assign sclk = pr_clk[pr_sel + 1];
assign spiclk = sclk ^ cpha;

/*** Shift register ***/

logic sh_loaded, sh_done, sh_din, sh_dout;
logic [$clog2(`DATA_N + 2) - 1 : 0] sh_cnt;
dataLogic sh_data;

assign sh_dout = sh_data[`DATA_N - 1];
assign sh_loaded = !sh_done && sh_cnt != 0;
assign sh_done = sh_cnt == `DATA_N + 1;

always_ff @(negedge spiclk, negedge n_sh_reset)
	if (~n_sh_reset) begin
		sh_data <= 'b0;
		sh_cnt <= 0;
	end else begin
		if (sh_cnt == 0) begin
			sh_data <= reg_data[`TX];
			sh_cnt <= sh_cnt + 1;
		end else if (~sh_done) begin
			sh_data <= {sh_data[`DATA_N - 2 : 0], sh_din};
			sh_cnt <= sh_cnt + 1;
		end else if (!reg_stat[`SPI_STAT_TXE_]) begin
			sh_data <= reg_data[`TX];
			sh_cnt <= 1;
		end
	end

// Short pulses

logic sh_loaded_s, sh_done_s;
pulse sh_loaded_pulse (.clk(clk), .n_reset(n_sh_reset), .d(sh_loaded), .q(sh_loaded_s));
pulse sh_done_pulse (.clk(clk), .n_reset(n_sh_reset), .d(sh_done), .q(sh_done_s));

// Bit capture

logic cap_din;
assign sh_din = cap_din;
//dff cap_dff (.clk(spiclk), .n_reset(sh_loaded), .d(cap_din), .q(sh_din));

/*** Control logic ***/

always_ff @(posedge clk, negedge enabled)
	if (~enabled) begin
		n_sh_reset <= 'b0;
		reg_data[`RX] <= `DATA_N'b0;
	end else begin
		if (we && periph_addr == `SPI_DATA) begin
			n_sh_reset <= 'b1;
		end else if (sh_done_s) begin
			if (reg_stat[`SPI_STAT_TXE_])
				n_sh_reset <= 'b0;
			reg_data[`RX] <= sh_data;
		end
	end

/*** Status report ***/

always_ff @(posedge clk, negedge enabled)
	if (~enabled) begin
		reg_stat <= `DATA_N'b0 | `SPI_STAT_TXE;
	end else begin
		if (n_sh_reset && sh_done_s)
			reg_stat[`SPI_STAT_RXNE_] <= 1'b1;
		else if (oe && periph_addr == `SPI_DATA)
			reg_stat[`SPI_STAT_RXNE_] <= 1'b0;
		if (we && periph_addr == `SPI_DATA)
			reg_stat[`SPI_STAT_TXE_] <= 1'b0;
		else if (sh_loaded_s)
			reg_stat[`SPI_STAT_TXE_] <= 1'b1;
	end

/*** IO logic ***/

assign cap_din = miso;

logic io_sck, io_mosi;
assign sck = enabled & (io_sck ^ cpol);
assign io_mosi = sh_dout;

dff io_sck_dff (.d((sh_loaded & sclk)), .q(io_sck), .*);
dff io_mosi_dff (.d(io_mosi), .q(mosi), .*);

assign interrupt = 1'b0;

endmodule
