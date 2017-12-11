module mem_test #(parameter BURST, BASE, SIZE) (
	input logic clkSYS, n_reset,

	// Memory interface
	output logic [23:0] addr,
	output logic [15:0] data,
	output logic req, wr,
	input logic ack,

	input logic [15:0] mem,
	input logic valid,

	// Debug info scan chain
	input logic clkDebug,
	input logic dbg_load, dbg_shift,
	input logic dbg_din,
	output logic dbg_dout,

	// Status
	output logic fail,
	input logic enable, reset, pattern
);

// Debug info scan
logic [7:0] dbg, dbg_sr;
assign dbg_dout = dbg_sr[7];
always_ff @(posedge clkDebug, negedge n_reset)
	if (~n_reset)
		dbg_sr <= 0;
	else if (dbg_load)
		dbg_sr <= dbg;
	else if (dbg_shift)
		dbg_sr <= {dbg_sr[6:0], dbg_din};

// Data buffer FIFO
logic rdreq, empty, full;
logic [15:0] fifo_q;
mem_test_fifo fifo0 (~n_reset, clkSYS, mem, rdreq, valid, empty, full, fifo_q);

// LFSR number generator
logic [32:0] lfsr;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		lfsr <= 1;
	else
		lfsr <= {lfsr[31:0], lfsr[32] ^ lfsr[19]};

// Rate limit
logic reload;
parameter N = 3;
logic [N - 1:0] cnt, cnt_ovf;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		cnt <= 0;
		cnt_ovf <= 0;
	end else if (reload) begin
		cnt <= 0;
		cnt_ovf <= 0;
	end else begin
		cnt <= cnt + 1;
		cnt_ovf <= cnt == {N{1'b1}};
	end

// Address generation
logic next;
logic [23:0] acnt, acnt_next;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		acnt <= 0;
	else if (next)
		acnt <= acnt_next;

logic frame;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		acnt_next <= 0;
		frame <= 0;
	end else if (acnt == SIZE - 1) begin
		acnt_next <= 0;
		frame <= 1;
	end else begin
		acnt_next <= acnt + 1;
		frame <= 0;
	end

always_ff @(posedge clkSYS)
	addr <= BASE + acnt;

// Data generation
logic data_update, data_reload;
logic [17:0] data_lfsr, data_lfsr_next, data_lfsr_latch;

always_ff @(posedge clkSYS)
	data_lfsr_next <= ~{data_lfsr[16:0], data_lfsr[17] ^ data_lfsr[10]};

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		data <= 0;
		data_lfsr <= 0;
		data_lfsr_latch <= 0;
	end else if (data_update) begin
		data <= lfsr[15:0];
		data_lfsr <= lfsr[17:0];
		data_lfsr_latch <= lfsr[17:0];
	end else if (data_reload) begin
		data <= data_lfsr_latch[15:0];
		data_lfsr <= data_lfsr_latch;
	end else if (next && pattern) begin
		data <= data_lfsr_next[15:0];
		data_lfsr <= data_lfsr_next;
	end

// States
enum int unsigned {WriteWait, Write, ReadWait, Read, Receive, VerifyWait, Verify} state;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		state <= WriteWait;
	end else if (state == WriteWait) begin
		if (cnt_ovf)
			state <= Write;
	end else if (state == Write) begin
		if (ack)
			state <= frame ? ReadWait : WriteWait;
	end else if (state == ReadWait) begin
		if (cnt_ovf)
			state <= Read;
	end else if (state == Read) begin
		if (ack)
			state <= Receive;
	end else if (state == Receive) begin
		if (full)
			state <= VerifyWait;
	end else if (state == VerifyWait) begin
		if (cnt_ovf)
			state <= Verify;
	end else if (state == Verify) begin
		if (empty)
			state <= frame ? WriteWait : ReadWait;
		else
			state <= VerifyWait;
	end

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		next <= 0;
	else
		case (state)
		Write:		next <= ack;
		Verify:		next <= 1;
		default:	next <= 0;
		endcase

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		reload <= 0;
	else
		case (state)
		WriteWait:	reload <= 0;
		ReadWait:	reload <= 0;
		VerifyWait:	reload <= 0;
		default:	reload <= 1;
		endcase

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset) begin
		req <= 0;
		wr <= 0;
	end else if (state == Write) begin
		req <= ~ack & enable;
		wr <= 1;
	end else if (state == Read) begin
		req <= ~ack & enable;
		wr <= 0;
	end else begin
		req <= 0;
		wr <= 'x;
	end

assign rdreq = state == VerifyWait && cnt_ovf;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		data_reload <= 0;
	else if (state == Write && ack && frame)
		data_reload <= 1;
	else
		data_reload <= 0;

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		data_update <= 0;
	else if (state == Verify && empty && frame)
		data_update <= 1;
	else
		data_update <= 0;

// Data verify
logic failed, verify;
always_ff @(posedge clkSYS)
begin
	verify <= state == Verify;
	failed <= verify && (fifo_q != data);
end

logic fail_clr;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		fail <= 0;
	else if (reset | fail_clr)
		fail <= 0;
	else if (failed)
		fail <= 1;

logic [6:0] cnt_fail;
always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		cnt_fail <= 0;
	else if (fail_clr)
		cnt_fail <= 0;
	else if (failed)
		cnt_fail <= cnt_fail + 1;

always_ff @(posedge clkDebug)
begin
	dbg <= {fail, cnt_fail};
	fail_clr <= dbg_load & dbg_sr[0];
end

endmodule
