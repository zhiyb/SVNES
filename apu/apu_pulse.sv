module apu_pulse #(parameter logic defect = 1'b0) (
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

logic [1:0] duty;
assign duty = regs[0][7:6];

logic lc_halt, env_loop;
assign lc_halt = regs[0][5], env_loop = lc_halt;

logic vol_con;
assign vol_con = regs[0][4];

logic [3:0] env_vol, env_period;
assign env_vol = regs[0][3:0], env_period = env_vol;

logic swp_en;
assign swp_en = regs[1][7];

logic [2:0] swp_period;
assign swp_period = regs[1][6:4];

logic swp_neg;
assign swp_neg = regs[1][3];

logic [2:0] swp_shift;
assign swp_shift = regs[1][2:0];

logic [10:0] timer_load_reg;
assign timer_load_reg = {regs[3][2:0], regs[2]};

logic [4:0] lc_load;
assign lc_load = regs[3][7:3];

// Envelope generator

logic [3:0] env_out;
apu_envelope e0 (
	.restart_cpu(we && sysbus.addr[1:0] == 2'd3), .loop(env_loop), 
	.period(env_period), .out(env_out), .*);

// Timer

logic [10:0] timer_load, swp_out;
logic swp_apply_cpu;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		timer_load <= 11'h0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		timer_load <= timer_load_reg;
	else if (swp_apply_cpu)
		timer_load <= swp_out;

logic timer_clk;
apu_timer #(.N(11)) t0 (
	.clk(apuclk), .n_reset(sys.n_reset), .clkout(timer_clk),
	.reload(1'b0), .loop(1'b1), .load(timer_load), .cnt());

logic gate_timer;
always_ff @(posedge timer_clk, negedge sys.n_reset)
	if (~sys.n_reset)
		gate_timer <= 1'b0;
	else
		gate_timer = timer_load[10:3] != 8'h0;

// Sweep

logic swp_reload;
flag_keeper swp_flag0 (.n_reset(sys.n_reset),
	.clk(sys.clk), .flag(we && sysbus.addr[1:0] == 2'd1),
	.clk_s(hframe), .clr(1'b1), .out(swp_reload));

logic gate_swp, swp_ovf, swp_ovf_add;
assign {swp_ovf_add, swp_out} = timer_load + ((timer_load >> swp_shift) ^ {11{swp_neg}}) + {10'h0, ~defect & swp_neg};
assign swp_ovf = swp_neg ^ swp_ovf_add;
assign gate_swp = swp_neg | ~swp_ovf_add;

logic [2:0] swp_div_cnt;
apu_timer #(.N(3)) swp_t0 (
	.clk(hframe), .n_reset(sys.n_reset), .clkout(),
	.reload(1'b0), .loop(swp_en), .load(swp_period), .cnt(swp_div_cnt));

logic swp_apply;
assign swp_apply = swp_en && swp_div_cnt == 3'h0 && swp_shift != 3'h0 && ~swp_ovf;
flag_detector swp_flag1 (.clk(sys.clk), .n_reset(sys.n_reset), .flag(swp_apply), .out(swp_apply_cpu));

// Waveform sequencer

logic seq_reset;
flag_keeper seq_flag0 (.n_reset(sys.n_reset),
	.clk(sys.clk), .flag(we && sysbus.addr[1:0] == 2'd3),
	.clk_s(timer_clk), .clr(1'b1), .out(seq_reset));

logic [2:0] seq_step;
always_ff @(posedge timer_clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		seq_step <= 3'h0;
	end else if (seq_reset) begin
		seq_step <= 3'h0;
	end else
		seq_step <= seq_step - 3'h1;

logic gate_seq;
always_comb
	case (duty)
	0:	gate_seq = seq_step == 3'b111 ? 1'b1 : 1'b0;
	1: gate_seq = seq_step[2:1] == 2'b11 ? 1'b1 : 1'b0;
	2: gate_seq = seq_step[2] == 1'b1 ? 1'b1 : 1'b0;
	3: gate_seq = seq_step[2:1] != 2'b11 ? 1'b1 : 1'b0;
	default:	gate_seq = 1'b0;
	endcase

// Length counter

logic gate_lc;
apu_length_counter lc0 (
	.halt(lc_halt), .load_cpu(we && sysbus.addr[1:0] == 2'd3),
	.idx(lc_load), .gate(gate_lc), .*);

// Output control

logic gate;
assign gate = gate_lc & gate_timer & gate_seq & gate_swp;
assign out = gate ? env_out : 4'b0;

endmodule
