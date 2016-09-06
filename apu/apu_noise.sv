module apu_noise (
	sys_if sys,
	sysbus_if sysbus,
	input logic apuclk, qframe, hframe,
	input logic sel, en,
	output logic act,
	output logic [3:0] out
);

// Registers

logic we;
assign we = sel & sysbus.we;

logic [7:0] regs[4];

always_ff @(negedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		for (int i = 0; i != 4; i++)
			regs[i] <= 8'b0;
	end else if (~en) begin
		for (int i = 0; i != 4; i++)
			regs[i] <= 8'b0;
	end else if (we) begin
		regs[sysbus.addr[1:0]] <= sysbus.data;
	end

// Separation of register fields

logic lc_halt, env_loop;
assign lc_halt = regs[0][5], env_loop = lc_halt;

logic vol_con;
assign vol_con = regs[0][4];

logic [3:0] env_vol, env_period;
assign env_vol = regs[0][3:0], env_period = env_vol;

logic mode;
assign mode = regs[2][7];

logic [3:0] period;
assign period = regs[2][3:0];

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

logic [11:0] timer_period;
apu_rom_noise_ntsc rom1 (.address(period), .aclr(~sys.n_reset), .clock(sys.nclk), .q(timer_period));

logic timer_tick;
logic [11:0] timer_cnt;

always_ff @(posedge apuclk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		timer_cnt <= 12'h0;
		timer_tick <= 1'b0;
	end else begin
		if (timer_cnt == 12'h0)
			timer_cnt <= timer_period;
		else
			timer_cnt <= timer_cnt - 12'h1;
		timer_tick <= timer_cnt == 12'h0;
	end

// LFSR

logic lfsr_fb;
logic [14:0] lfsr;

always_ff @(posedge timer_tick, negedge sys.n_reset)
	if (~sys.n_reset)
		lfsr <= 15'h1;
	else
		lfsr <= {lfsr_fb, lfsr[14:1]};

assign lfsr_fb = lfsr[0] ^ (mode ? lfsr[6] : lfsr[1]);

logic gate_lfsr;
assign gate_lfsr = ~lfsr[0];

// Length counter

logic load_lc, load_lc_clr;
always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		load_lc <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		load_lc <= 1'b1;
	else if (load_lc_clr)
		load_lc <= 1'b0;

logic gate_lc;
logic [7:0] cnt, cnt_load;
assign act = cnt != 8'h0;
apu_rom_length rom0 (.address(lc_load), .aclr(~sys.n_reset), .clock(sys.nclk), .q(cnt_load));

always_ff @(posedge hframe, negedge sys.n_reset)
	if (~sys.n_reset) begin
		cnt <= 8'b0;
		load_lc_clr <= 1'b0;
		gate_lc <= 1'b0;
	end else begin
		load_lc_clr <= load_lc;
		gate_lc <= cnt != 8'b0;
		if (~en)
			cnt <= 8'b0;
		else if (load_lc)
			cnt <= cnt_load;
		else if (~lc_halt && cnt != 8'b0)
			cnt <= cnt - 8'b1;
	end

// Output control

logic gate;
assign gate = en & gate_lfsr & gate_lc;
assign out = gate ? env_out : 4'b0;

endmodule
