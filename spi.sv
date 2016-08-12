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

/*** Internal registers ***/

logic [`DATA_N - 1 : 0] reg_ctrl, reg_stat, reg_data[2];

/*** Register read & write ***/

logic we, oe;
assign we = periph_sel & bus_we;
assign oe = periph_sel & bus_oe;

logic [`DATA_N - 1 : 0] periph_data;
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
logic [$clog2(`DATA_N + 2) - 1 : 0] sh_cnt;
logic [`DATA_N - 1 : 0] sh_data;

assign sh_dout = sh_data[`DATA_N - 1];
assign sh_done = sh_cnt == `DATA_N + 1;

always_ff @(negedge spiclk, negedge n_reset, negedge n_sh_reset)
	if (~n_reset || ~n_sh_reset) begin
		sh_data <= 'b0;
		sh_cnt <= 0;
	end else begin
		if (sh_cnt == 0) begin
			sh_data <= reg_data[`TX];
			sh_cnt <= sh_cnt + 1;
		end else if (~sh_done) begin
			sh_data <= {sh_data[`DATA_N - 2 : 0], sh_din};
			sh_cnt <= sh_cnt + 1;
		end
	end

/*** Bit capture ***/

logic cap_din;

always_ff @(posedge spiclk, negedge n_reset)
	if (~n_reset)
		sh_din <= 'b0;
	else
		sh_din <= cap_din;

/*** Control logic and status report ***/

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		n_sh_reset <= 'b0;
		reg_data[`RX] <= `DATA_N'b0;
		reg_stat <= `DATA_N'b0;
	end else if (enabled) begin
		if (we && periph_addr == `SPI_DATA) begin
			n_sh_reset <= 'b1;
		end else if (n_sh_reset && sh_done) begin
			n_sh_reset <= 'b0;
			reg_data[`RX] <= sh_data;
			reg_stat <= reg_stat | `SPI_STAT_FLAG;
		end
	end else
		n_sh_reset <= 'b0;

/*** IO logic ***/

assign cs = enabled;
assign sck = enabled & ((n_sh_reset & sclk) ^ cpol);
assign mosi = sh_dout;
assign cap_din = miso;

assign interrupt = 1'b0;

endmodule
