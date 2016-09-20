`include "defines.h"

module spi (
	sys_if sys,
	input logic sel,
	periphbus_if pbus,
	// Interrupt
	output logic interrupt,
	// IO ports
	input logic cs, miso,
	output logic mosi, sck
);

/*** Internal registers ***/

logic [7:0] reg_ctrl, reg_stat, reg_data[2];

`define RX	0
`define TX	1

/*** Register read & write ***/

logic we, oe;
assign we = sel & pbus.we;
assign oe = sel & ~pbus.we;

logic [7:0] periph_data;
assign pbus.data = oe ? periph_data : 8'bz;

always_comb
begin
	case (pbus.addr)
	`SPI_CTRL:	periph_data = reg_ctrl & `SPI_CTRL_MASK;
	`SPI_STAT:	periph_data = reg_stat & `SPI_STAT_MASK;
	`SPI_DATA:	periph_data = reg_data[`RX];
	default:		periph_data = 8'h0;
	endcase
end

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		reg_ctrl <= 8'h0;
		reg_data[`TX] <= 8'h0;
	end else if (we) begin
		case (pbus.addr)
		`SPI_CTRL:	reg_ctrl <= pbus.data;
		`SPI_DATA:	reg_data[`TX] <= pbus.data;
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
logic [PR_N:0] pr_clk;
prescaler #(.n(PR_N)) p0 (.n_reset(sys.n_reset && n_sh_reset), .clk(sys.clk), .counter(pr_clk));

logic sclk, spiclk;
assign sclk = pr_clk[pr_sel + 1];
assign spiclk = sclk ^ cpha;

/*** Shift register ***/

logic sh_loaded, sh_done, sh_din, sh_dout;
logic [3:0] sh_cnt;
logic [7:0] sh_data;

assign sh_dout = sh_data[7];
assign sh_loaded = !sh_done && sh_cnt != 0;
assign sh_done = sh_cnt == 4'd9;

always_ff @(negedge spiclk, negedge n_sh_reset)
	if (~n_sh_reset) begin
		sh_data <= 'b0;
		sh_cnt <= 0;
	end else begin
		if (sh_cnt == 0) begin
			sh_data <= reg_data[`TX];
			sh_cnt <= sh_cnt + 4'h1;
		end else if (~sh_done) begin
			sh_data <= {sh_data[6:0], sh_din};
			sh_cnt <= sh_cnt + 4'h1;
		end else if (!reg_stat[`SPI_STAT_TXE_]) begin
			sh_data <= reg_data[`TX];
			sh_cnt <= 4'h1;
		end
	end

// Short pulses

logic sh_loaded_s, sh_done_s;
pulse sh_loaded_pulse (.clk(sys.clk), .n_reset(n_sh_reset), .d(sh_loaded), .q(sh_loaded_s));
pulse sh_done_pulse (.clk(sys.clk), .n_reset(n_sh_reset), .d(sh_done), .q(sh_done_s));

// Bit capture

logic cap_din;
assign sh_din = cap_din;
//dff cap_dff (.clk(spiclk), .n_reset(sh_loaded), .d(cap_din), .q(sh_din));

/*** Control logic ***/

always_ff @(posedge sys.clk, negedge enabled)
	if (~enabled) begin
		n_sh_reset <= 1'b0;
		reg_data[`RX] <= 8'b0;
	end else begin
		if (we && pbus.addr == `SPI_DATA) begin
			n_sh_reset <= 1'b1;
		end else if (sh_done_s) begin
			if (reg_stat[`SPI_STAT_TXE_])
				n_sh_reset <= 1'b0;
			reg_data[`RX] <= sh_data;
		end
	end

/*** Status report ***/

logic [7:0] reg_stat_in;

always_comb
begin
	reg_stat_in = reg_stat;
	if (n_sh_reset && sh_done_s)
		reg_stat_in |= `SPI_STAT_RXNE;
	else if (oe && pbus.addr == `SPI_DATA)
		reg_stat_in &= ~`SPI_STAT_RXNE;
	if (we && pbus.addr == `SPI_DATA)
		reg_stat_in &= ~`SPI_STAT_TXE;
	else if (sh_loaded_s)
		reg_stat_in |= `SPI_STAT_TXE;
end

always_ff @(posedge sys.clk, negedge enabled)
	if (~enabled)
		reg_stat <= `SPI_STAT_TXE;
	else
		reg_stat <= reg_stat_in;

/*** IO logic ***/

assign cap_din = miso;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		sck <= 1'b0;
	else
		sck <= enabled & ((sh_loaded & sclk) ^ cpol);

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		mosi <= 1'b0;
	else
		mosi <= sh_dout;

assign interrupt = 1'b0;

endmodule
