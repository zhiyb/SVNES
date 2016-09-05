module apu_pulse #(parameter logic defect = 1'b0) (
	sys_if sys,
	sysbus_if sysbus,
	input logic apuclk, qframe, hframe,
	input logic sel, en,
	output logic act,
	output logic [3:0] out
);

logic [3:0] audio;
assign out = en ? audio : 4'b0;

// Registers

logic we, oe;
assign we = sel & sysbus.we;
assign oe = sel & ~sysbus.we;

logic [7:0] regs[4];
//assign sysbus.data = oe ? regs[sysbus.addr[1:0]] : {`DATA_N{1'bz}};

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		for (int i = 0; i != 4; i++)
			regs[i] <= 8'b0;
	end else if (~en) begin
		for (int i = 0; i != 4; i++)
			regs[i] <= 8'b0;
	end else if (we) begin
		regs[sysbus.addr[1:0]] <= sysbus.data;
	end

// Separation of registers

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

logic env_start, env_start_clr;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		env_start <= 1'b0;
	else if (~en || env_start_clr)
		env_start <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		env_start <= 1'b1;

always_ff @(posedge qframe, negedge sys.n_reset)
	if (~sys.n_reset)
		env_start_clr <= 1'b0;
	else
		env_start_clr <= env_start;

// Envelope divider & decay counter

logic [3:0] env_div_cnt, env_cnt;

always_ff @(posedge qframe, negedge sys.n_reset)
	if (~sys.n_reset) begin
		env_div_cnt <= 4'h0;
		env_cnt <= 4'h0;
	end else if (env_start) begin
		env_div_cnt <= env_period;
		env_cnt <= 4'hf;
	end else if (env_div_cnt == 4'h0) begin
		env_div_cnt <= env_period;
		if (env_loop || env_cnt != 4'h0)
			env_cnt <= env_cnt - 4'h1;
	end else
		env_div_cnt <= env_div_cnt - 4'h1;

logic [3:0] env_out;
assign env_out = vol_con ? env_vol : env_cnt;

// Timer

logic timer_reload;
assign timer_reload = we && sysbus.addr[1:0] == 2'd3;

logic [10:0] timer_load;
logic [10:0] swp_out;
logic swp_apply_cpu;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		timer_load <= 11'h0;
	else if (timer_reload)
		timer_load <= timer_load_reg;
	else if (swp_apply_cpu)
		timer_load <= swp_out;

logic gate_timer;
logic [10:0] timer_cnt;
logic timer_tick;

always_ff @(posedge apuclk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		timer_cnt <= 11'h0;
		timer_tick <= 1'b0;
		gate_timer <= 1'b0;
	end else if (~en) begin
		timer_cnt <= 11'h0;
		timer_tick <= 1'b0;
		gate_timer <= 1'b0;
	end else if (timer_cnt == 11'h0) begin
		timer_cnt <= timer_load;
		timer_tick <= 1'b1;
		if (timer_load[10:3] == 8'h0)
			gate_timer <= 1'b0;
		else
			gate_timer <= 1'b1;
	end else begin
		timer_cnt <= timer_cnt - 11'h1;
		timer_tick <= 1'b0;
	end

// Sweep

logic swp_reload, swp_reload_clr;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_reload <= 1'b0;
	else if (~en || swp_reload_clr)
		swp_reload <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd1)
		swp_reload <= 1'b1;

always_ff @(posedge hframe, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_reload_clr <= 1'b0;
	else
		swp_reload_clr <= swp_reload;

logic gate_swp, swp_ovf, swp_ovf_add, swp_apply, swp_apply_delayed;
assign {swp_ovf_add, swp_out} = timer_load + ((timer_load >> swp_shift) ^ {11{swp_neg}}) + {10'h0, ~defect & swp_neg};
assign swp_ovf = swp_neg ^ swp_ovf_add;
assign gate_swp = swp_neg | ~swp_ovf_add;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_apply_delayed <= 1'b0;
	else
		swp_apply_delayed <= swp_apply;

assign swp_apply_cpu = swp_apply & ~swp_apply_delayed;

logic [2:0] swp_div_cnt;

assign swp_apply = swp_en && swp_div_cnt == 3'h0 && swp_shift != 3'h0 && ~swp_ovf;

always_ff @(posedge hframe, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_div_cnt <= 3'h0;
	else begin
		if (swp_reload)
			swp_div_cnt <= swp_period;
		else if (swp_div_cnt == 3'h0) begin
			if (swp_en)
				swp_div_cnt <= swp_period;
		end else
			swp_div_cnt <= swp_div_cnt - 3'h1;
	end

// Waveform sequencer

logic [2:0] seq_step;

always_ff @(posedge timer_tick, negedge sys.n_reset)
	if (~sys.n_reset) begin
		seq_step <= 3'h0;
	end else if (~en) begin
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

logic load_lc, load_lc_cpu;
always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		load_lc_cpu <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		load_lc_cpu <= 1'b1;
	else if (load_lc)
		load_lc_cpu <= 1'b0;

logic gate_lc;
assign act = gate_lc;

logic [7:0] cnt, cnt_load;
apu_rom_length rom0 (.address(lc_load), .clock(sys.nclk), .q(cnt_load));

always_ff @(posedge hframe, negedge sys.n_reset)
	if (~sys.n_reset) begin
		cnt <= 8'b0;
		load_lc <= 1'b0;
		gate_lc <= 1'b0;
	end else begin
		load_lc <= load_lc_cpu;
		if (cnt == 8'b0)
			gate_lc <= 1'b0;
		else
			gate_lc <= 1'b1;
		if (~en)
			cnt <= 8'b0;
		else if (load_lc_cpu)
			cnt <= cnt_load;
		else if (~lc_halt && cnt != 8'b0)
			cnt <= cnt - 8'b1;
	end

// Output control

logic gate;
assign gate = en & gate_lc & gate_timer & gate_seq & gate_swp;

assign audio = gate ? env_out : 4'b0;

endmodule
