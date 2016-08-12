`include "config.sv"

module spi (
	// Peripheral clock, reset and buses
	input logic clk, n_reset,
	input logic bus_we, bus_oe, periph_sel,
	input logic [`PERIPH_N - 1 : 0] periph_addr,
	inout logic [`DATA_N - 1 : 0] bus_data
	// Interrupt
	output logic interrupt,
	// IO ports
	input logic miso,
	output logic cs, mosi, sck,
);

/*** Bus and peripheral arbiter ***/

logic we, oe;
assign we = periph_sel & bus_we, oe = periph_sel & bus_oe;

logic [`DATA_N - 1 : 0] periph_data;
assign bus_data = oe ? periph_data : {`DATA_N{1'bz}};

/*** Internal registers and RW control ***/

logic [`DATA_N - 1 : 0] reg_ctrl, reg_stat, reg_data[2];

always_comb
begin
	periph_data = `DATA_N'b0;
	case (periph_addr)
	`SPI_CTRL:	periph_data = reg_ctrl & `SPI_CTRL_MASK;
	`SPI_STAT:	periph_data = reg_stat & `SPI_STAT_MASK;
	`SPI_DATA:	periph_data = reg_data[`R];
	endcase
end

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		reg_ctrl <= `DATA_N'b0;
		reg_stat <= `DATA_N'b0;
		reg_data[`W] <= `DATA_N'b0;
		reg_data[`R] <= `DATA_N'b0;
	end else begin
		if (we) begin
			case (periph_addr)
			`SPI_CTRL:	reg_ctrl <= bus_data;
			`SPI_DATA:	begin
				reg_data <= bus_data;
			end
			endcase
		end
	end

/*** Internal logic signals ***/

logic enabled;
assign enabled = (reg_ctrl & `SPI_CTRL_EN) != 'b0;

logic cpha, cpol;
assign cpha = (reg_ctrl & `SPI_CTRL_CPOL) != 'b0;
assign cpol = (reg_ctrl & `SPI_CTRL_CPHA) != 'b0;

parameter PR_N = 7;
logic [PR_N : 0] pr_clk;
assign pr_clk[0] = clk;
prescaler #(.n(PR_N)) p0 (.n_reset(n_reset), .clk(clk), .counter(pr_clk[PR_N : 1]));

logic sclk, sdo;
assign sclk = pr_clk[reg_ctrl[2:0]];
assign sck = sclk ^ cpol;
assign cs = enabled;

logic spiclk;
assign spiclk = sclk ^ cpha;

logic [$clog2(`DATA_N * 2) - 1 : 0] cnt;

logic [`DATA_N - 1 : 0] sh_data;
assign mosi = sh_data[`DATA_N - 1];

always_ff @(posedge spiclk, negedge n_reset)
	if (~n_reset) begin
		cnt <= 0;
	end else begin
		if (cnt == 0) begin
		end else begin
			cnt <= cnt - 1;
		end
	end

endmodule
