`include "config.sv"

module spi (
	// Peripheral clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe, periph_sel,
	input logic [`PERIPH_N - 1 : 0] periph_addr,
	inout logic [`DATA_N - 1 : 0] bus_data,
	// Interrupt
	output logic interrupt,
	// IO ports
	input logic miso,
	output logic cs, mosi, sck
);

/*** Bus and peripheral arbiter ***/

logic we, oe;
assign we = periph_sel & bus_we, oe = periph_sel & bus_oe;

logic [`DATA_N - 1 : 0] periph_data;
assign bus_data = oe ? periph_data : {`DATA_N{1'bz}};

/*** Internal registers ***/

logic [`DATA_N - 1 : 0] reg_ctrl, reg_stat, reg_data[2];

/*** Control signals ***/

logic enabled, cpha, cpol;
assign enabled = (reg_ctrl & `SPI_CTRL_EN) != 'b0;
assign cpha = (reg_ctrl & `SPI_CTRL_CPOL) != 'b0;
assign cpol = (reg_ctrl & `SPI_CTRL_CPHA) != 'b0;

logic [2 : 0] pr_sel;
assign pr_sel = reg_ctrl[2:0];

/*** Clock prescaler ***/

parameter PR_N = 7;
logic [PR_N : 0] pr_clk;
assign pr_clk[0] = clk;
prescaler #(.n(PR_N)) p0 (.n_reset(n_reset), .clk(clk), .counter(pr_clk[PR_N : 1]));

logic sclk, spiclk;
assign sclk = pr_clk[pr_sel];
assign spiclk = sclk ^ cpha;

/*** Shift register ***/

logic n_sh_reset, sh_done, sh_din, sh_dout;
logic [$clog2(`DATA_N) - 1 : 0] sh_cnt;
logic [`DATA_N - 1 : 0] sh_data;

assign sh_dout = sh_data[`DATA_N - 1];
assign sh_done = sh_cnt == `DATA_N;

always_ff @(posedge spiclk, negedge n_reset, negedge n_sh_reset)
	if (~n_reset || ~n_sh_reset) begin
		sh_data <= 'b0;
		sh_cnt <= 0;
	end else begin
		if (sh_cnt == 0) begin
			sh_data <= reg_data[`TX];
			sh_cnt <= sh_cnt + 1;
		end else begin
			sh_data <= {sh_data[`DATA_N - 2 : 0], sh_din};
			if (~sh_done)
				sh_cnt <= sh_cnt + 1;
		end
	end

/*** IO logic ***/

assign cs = enabled;
assign sck = enabled & ((n_sh_reset & sclk) ^ cpol);
assign mosi = sh_dout;
assign sh_din = miso;

assign interrupt = 1'b0;

/*** Register RW operation ***/

always_comb
begin
	periph_data = `DATA_N'b0;
	case (periph_addr)
	`SPI_CTRL:	periph_data = reg_ctrl & `SPI_CTRL_MASK;
	`SPI_STAT:	periph_data = reg_stat & `SPI_STAT_MASK;
	`SPI_DATA:	periph_data = reg_data[`RX];
	endcase
end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		reg_ctrl <= `DATA_N'b0;
		reg_stat <= `DATA_N'b0;
		reg_data[`TX] <= `DATA_N'b0;
		reg_data[`RX] <= `DATA_N'b0;
	end else begin
		if (we) begin
			case (periph_addr)
			`SPI_CTRL:	reg_ctrl <= bus_data;
			`SPI_DATA:
				if (enabled) begin
					reg_data[`TX] <= bus_data;
				end
			endcase
		end
	end

endmodule
