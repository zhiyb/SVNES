module mem_test #(parameter BURST, BASE, SIZE) (
	input logic clkSYS, n_reset,

	input logic [15:0] mem,
	input logic valid,

	output logic [23:0] addr,
	output logic [15:0] data,
	output logic req, wr,
	input logic ack,

	output logic fail,
	input logic reset, pattern
);

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
		req <= ~ack;
		wr <= 1;
	end else if (state == Read) begin
		req <= ~ack;
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

always_ff @(posedge clkSYS, negedge n_reset)
	if (~n_reset)
		fail <= 0;
	else if (reset)
		fail <= 0;
	else if (failed)
		fail <= 1;

endmodule
