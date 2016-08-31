module interrupts (
	sys_if sys,
	input logic i, irq, nmi,
	input logic int_handled,
	output logic int_evnt,
	output logic [15:0] int_addr
);

`define NMI	0
`define RST	1
`define IRQ 2

parameter logic [15:0] addr[3] = '{16'hfffa, 16'hfffc, 16'hfffe};

logic int_nmi, int_rst, int_irq;
assign int_evnt = int_nmi | int_rst | (~i & int_irq);
assign int_addr = int_nmi ? addr[`NMI] : (int_rst ? addr[`RST] : addr[`IRQ]);

logic clr_nmi, clr_rst;
assign clr_nmi = int_handled & int_nmi;
assign clr_rst = int_handled & ~int_nmi;

logic nmi_prev;
always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		int_nmi <= 1'b0;
		nmi_prev <= 1'b0;
	end else begin
		nmi_prev <= nmi;
		if (clr_nmi)
			int_nmi <= 1'b0;
		else if (nmi_prev & ~nmi)
			int_nmi <= 1'b1;
	end

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		int_rst <= 1'b1;
	end else if (clr_rst) begin
		int_rst <= 1'b0;
	end

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		int_irq <= 1'b0;
	end else begin
		int_irq <= ~i & ~irq;
	end

endmodule
