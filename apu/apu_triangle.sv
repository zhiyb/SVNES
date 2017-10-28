module apu_triangle (
	input logic clk, dclk, n_reset,

	input logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	input logic sys_rw,

	input logic apuclk, qframe, hframe,
	input logic sel, en,
	output logic act,
	output logic [3:0] out
);

// Registers

logic we;
logic [7:0] regs[4];
apu_registers r0 (.*);

// Separation of register fields

logic flag_ctrl, lc_halt;
assign flag_ctrl = regs[0][7], lc_halt = flag_ctrl;

logic [6:0] cnt_load_reg;
assign cnt_load_reg = regs[0][6:0];

logic [10:0] timer_load_reg;
assign timer_load_reg = {regs[3][2:0], regs[2]};

logic [4:0] lc_load_reg;
assign lc_load_reg = regs[3][7:3];

// Timer

logic timer_clk;
apu_timer #(.N(11)) t0 (
	.clk(clk), .n_reset(n_reset), .clkout(timer_clk),
	.reload(we && sys_addr[1:0] == 2'd3), .loop(1'b1),
	.load(timer_load_reg), .cnt());

// Linear counter

logic linear_reload;
flag_keeper flag0 (.n_reset(n_reset),
	.clk(clk), .flag(we && sys_addr[1:0] == 2'd3),
	.clk_s(qframe), .clr(~flag_ctrl), .out(linear_reload));

logic [6:0] linear_cnt;
apu_timer #(.N(7)) lt0 (
	.clk(qframe), .n_reset(n_reset), .clkout(),
	.reload(linear_reload), .loop(1'b0),
	.load(cnt_load_reg), .cnt(linear_cnt));

logic gate_linear;
assign gate_linear = linear_cnt != 7'h0;

// Length counter

logic gate_lc;
apu_length_counter lc0 (
	.halt(lc_halt), .load_cpu(we && sys_addr[1:0] == 2'd3),
	.idx(lc_load_reg), .gate(gate_lc), .*);

// Waveform sequencer

logic seq_clk;
assign seq_clk = gate_linear & gate_lc & timer_clk;

logic [4:0] seq_cnt;
always_ff @(posedge seq_clk, negedge n_reset)
	if (~n_reset)
		seq_cnt <= 5'h0;
	else
		seq_cnt <= seq_cnt + 5'h1;

logic [3:0] seq_out;
assign seq_out = {4{seq_cnt[4]}} ^ seq_cnt[3:0];

assign out = en ? seq_out : 4'h0;

endmodule
