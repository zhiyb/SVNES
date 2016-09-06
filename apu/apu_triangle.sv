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
	end else if (~en) begin
		timer_cnt <= 11'h0;
		timer_tick <= 1'b0;
	end else if (timer_reload) begin
		timer_cnt <= timer_load_reg;
		timer_tick <= 1'b1;
	end else if (timer_cnt == 11'h0) begin
		timer_cnt <= timer_load_reg;
		timer_tick <= 1'b1;
	end else begin
		timer_cnt <= timer_cnt - 11'h1;
		timer_tick <= 1'b0;
	end

// Waveform sequencer

logic seq_clk;
assign seq_clk = timer_tick & ~sys.clk;

logic seq_reset, seq_reset_clr;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		seq_reset <= 1'b0;
	else if (seq_reset_clr)
		seq_reset <= 1'b0;
	else if (timer_reload)
		seq_reset <= 1'b1;

always_ff @(posedge seq_clk, negedge sys.n_reset)
	if (~sys.n_reset)
		seq_reset_clr <= 1'b0;
	else
		seq_reset_clr <= seq_reset;

// Length counter

assign act = 1'b0;

// Output control

logic gate;

assign out = gate ? 4'b0 : 4'b0;

endmodule
