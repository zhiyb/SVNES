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
logic [7:0] regs[4];
apu_registers r0 (.*);

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

logic [3:0] env_out;
apu_envelope e0 (
	.restart_cpu(we && sysbus.addr[1:0] == 2'd3), .loop(env_loop), 
	.period(env_period), .out(env_out), .*);

// Timer

logic [11:0] timer_load;
apu_rom_noise_ntsc rom1 (.address(period), .aclr(~sys.n_reset), .clock(sys.nclk), .q(timer_load));

logic timer_clk;
apu_timer #(.N(12)) t0 (
	.clk(apuclk), .n_reset(sys.n_reset), .clkout(timer_clk),
	.reload(1'b0), .loop(1'b1), .load(timer_load), .cnt());

// LFSR

logic lfsr_fb;
logic [14:0] lfsr_data;
lfsr #(.N(15), .RESET(15'h1)) l0 (.clk(timer_clk), .n_reset(sys.n_reset), .fb(lfsr_fb), .data(lfsr_data));

assign lfsr_fb = lfsr_data[0] ^ (mode ? lfsr_data[6] : lfsr_data[1]);

logic gate_lfsr;
assign gate_lfsr = ~lfsr_data[0];

// Length counter

logic gate_lc;
apu_length_counter lc0 (
	.halt(lc_halt), .load_cpu(we && sysbus.addr[1:0] == 2'd3),
	.idx(lc_load), .gate(gate_lc), .*);

// Output control

logic gate;
assign gate = gate_lfsr & gate_lc;
assign out = gate ? env_out : 4'b0;

endmodule
