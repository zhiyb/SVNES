import sdram_types::*;

module sdram_sys #(
	// Address bus size, data bus size
	parameter AN = 24, DN = 16, BURST = 8
) (
	input logic clkSYS, n_reset,
	output logic n_reset_mem,

	// Periodic counter
	input logic icnt_ovf_latch,

	// FIFO interface
	input logic full,
	output logic fifo_wrreq,
	output data_t fifo_in,

	// System bus request interface
	input logic [AN - 1:0] req_addr,
	input logic [DN - 1:0] req_data,
	input logic [1:0] req_id,
	input logic req, req_wr,
	output logic req_ack
);

// {{{ Initialisation and auto refresh
logic icnt_ovf, icnt_ovf_clr;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		icnt_ovf <= 1'b0;
	else if (icnt_ovf_latch)
		icnt_ovf <= 1'b1;
	else if (icnt_ovf_clr)
		icnt_ovf <= 1'b0;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		n_reset_mem <= 1'b0;
	else if (icnt_ovf)
		n_reset_mem <= 1'b1;
// }}}

// {{{ Command generation
// Command status
enum int unsigned {Powerup, IPrecharge, IRefresh, IRefresh2, IMode,
	Idle, PrechargeAll, Refresh,
	Request, Active, Precharge, Read, Write} state;

logic stall;
assign stall = full;

// Request interpret
logic [1:0] req_ba;
logic [8:0] req_column;
logic [12:0] req_row;
assign {req_ba, req_row, req_column} = req_addr;

// System interface
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		req_ack <= 1'b0;
	else if (~stall && (state == Read || state == Write))
		req_ack <= 1'b1;
	else
		req_ack <= 1'b0;

logic wrreq;
assign fifo_wrreq = wrreq && ~stall;

// Bank statuses
logic [3:0] active, match;
logic [12:0] bank_row[4];

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		active <= 4'b0000;
		match <= 4'b0000;
		for (int i = 0; i < 4; i++)
			bank_row[i] <= 0;
	end else begin
		if (state == Active) begin
			active[req_ba] <= 1'b1;
			bank_row[req_ba] <= req_row;
		end else if (state == Precharge)
			active[req_ba] <= 1'b0;
		else if (state == PrechargeAll)
			active <= 4'b0000;
		for (int i = 0; i < 4; i++)
			match[i] <= active[i] && req_row == bank_row[i];
	end

// Periodic refresh clear
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		icnt_ovf_clr <= 1'b0;
	else if (~stall && (state == Powerup || state == Idle))
		icnt_ovf_clr <= 1'b1;
	else
		icnt_ovf_clr <= 1'b0;

// Command sequencer
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		state <= Powerup;
		fifo_in.cmd <= NOP;
		wrreq <= 1'b0;
	end else if (~stall) begin
		if (state == Powerup) begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			if (icnt_ovf)
				state <= IPrecharge;
		end else if (state == IPrecharge) begin
			fifo_in.cmd <= PALL;
			wrreq <= 1'b1;
			state <= IRefresh;
		end else if (state == IRefresh) begin
			fifo_in.cmd <= REF;
			wrreq <= 1'b1;
			state <= IRefresh2;
		end else if (state == IRefresh2) begin
			fifo_in.cmd <= REF;
			wrreq <= 1'b1;
			state <= IMode;
		end else if (state == IMode) begin
			fifo_in.cmd <= MRS;
			wrreq <= 1'b1;
			state <= Idle;
		end else if (state == PrechargeAll) begin
			fifo_in.cmd <= PALL;
			wrreq <= 1'b1;
			state <= Refresh;
		end else if (state == Refresh) begin
			fifo_in.cmd <= REF;
			wrreq <= 1'b1;
			state <= req ? Request : Idle;
		end else if (state == Idle) begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			if (icnt_ovf)
				state <= PrechargeAll;
			else if (req && ~req_ack)
				state <= Request;
		end else if (state == Request) begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			if (match[req_ba])
				state <= req_wr ? Write : Read;
			else if (active[req_ba])
				state <= Precharge;
			else
				state <= Active;
		end else if (state == Precharge) begin
			fifo_in.cmd <= PRE;
			wrreq <= 1'b1;
			state <= Active;
		end else if (state == Active) begin
			fifo_in.cmd <= ACT;
			wrreq <= 1'b1;
			state <= req_wr ? Write : Read;
		end else if (state == Read) begin
			fifo_in.cmd <= READ;
			wrreq <= 1'b1;
			state <= Idle;
		end else if (state == Write) begin
			fifo_in.cmd <= WRITE;
			wrreq <= 1'b1;
			state <= Idle;
		end else begin
			fifo_in.cmd <= NOP;
			wrreq <= 1'b0;
			state <= Idle;
		end
	end

// Data generation
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		fifo_in.ba <= 2'h0;
		fifo_in.d <= 25'h0;
	end else if (~stall) begin
		if (state == Read) begin
			fifo_in.ba <= req_ba;
			fifo_in.d.column <= req_column;
			fifo_in.d.data <= {14'bx, req_id};
		end else if (state == Write) begin
			fifo_in.ba <= req_ba;
			fifo_in.d.column <= req_column;
			fifo_in.d.data <= req_data;
		end else if (state == Active) begin
			fifo_in.ba <= req_ba;
			fifo_in.d.column <= 'x;
			fifo_in.d.data <= {3'bx, req_row};
		end else if (state == Precharge) begin
			fifo_in.ba <= req_ba;
			fifo_in.d <= 'x;
		end else begin
			fifo_in.ba <= 'x;
			fifo_in.d <= 'x;
		end
	end
// }}}

endmodule
