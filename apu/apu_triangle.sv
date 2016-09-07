module apu_triangle (
	sys_if sys,
	sysbus_if sysbus,
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

logic timer_reload;
assign timer_reload = we && sysbus.addr[1:0] == 2'd3;

logic timer_clk;
logic [10:0] timer_cnt;

apu_timer #(.N(11)) t0 (
	.clk(sys.clk), .n_reset(sys.n_reset), .clkout(timer_clk),
	.reload(we && sysbus.addr[1:0] == 2'd3),
	.load(timer_load_reg), .cnt(timer_cnt));

// Linear counter

logic linear_reload, linear_reload_clr;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		linear_reload <= 1'b0;
	else if (linear_reload_clr)
		linear_reload <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		linear_reload <= 1'b1;

always_ff @(posedge qframe, negedge sys.n_reset)
	if (~sys.n_reset)
		linear_reload_clr <= 1'b0;
	else if (linear_reload)
		linear_reload_clr <= ~flag_ctrl;
	else
		linear_reload_clr <= 1'b0;

logic [6:0] linear_cnt;

always_ff @(posedge qframe, negedge sys.n_reset)
	if (~sys.n_reset)
		linear_cnt <= 7'h0;
	else if (linear_reload)
		linear_cnt <= cnt_load_reg;
	else if (linear_cnt != 7'h0)
		linear_cnt <= linear_cnt - 7'h1;

logic gate_linear;
assign gate_linear = linear_cnt != 7'h0;

// Length counter

logic gate_lc;
apu_length_counter lc0 (
	.halt(lc_halt), .load_cpu(we && sysbus.addr[1:0] == 2'd3),
	.idx(lc_load_reg), .gate(gate_lc), .*);

// Waveform sequencer

logic seq_clk;
assign seq_clk = gate_linear & gate_lc & timer_clk;

logic [4:0] seq_cnt;

always_ff @(posedge seq_clk, negedge sys.n_reset)
	if (~sys.n_reset)
		seq_cnt <= 5'h0;
	else
		seq_cnt <= seq_cnt + 5'h1;

logic [3:0] seq_out;
assign seq_out = {4{seq_cnt[4]}} ^ seq_cnt[3:0];

// Output control

assign out = en ? seq_out : 4'h0;

endmodule
