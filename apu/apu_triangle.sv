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

logic timer_tick;
logic [10:0] timer_cnt;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		timer_cnt <= 11'h0;
		timer_tick <= 1'b0;
	end else begin
		if (~en)
			timer_cnt <= 11'h0;
		else if (timer_reload || timer_cnt == 11'h0)
			timer_cnt <= timer_load_reg;
		else
			timer_cnt <= timer_cnt - 11'h1;
		timer_tick <= timer_cnt == 11'h0;
	end

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
apu_rom_length rom0 (.address(lc_load_reg), .aclr(~sys.n_reset), .clock(sys.nclk), .q(cnt_load));

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

assign act = cnt != 8'h0;

// Waveform sequencer

logic seq_clk;
assign seq_clk = gate_linear & gate_lc & timer_tick & ~sys.clk;

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
