module apu (
	input logic clk, dclk, n_reset,

	input logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	output wire sys_rdy,
	input logic sys_rw,

	output wire [15:0] bus_addr,
	input logic bus_rdy,
	output logic bus_req,
	
	output logic irq,
	output logic [7:0] out
);

logic apuclk, qframe, hframe;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		apuclk <= 1'b0;
	else
		apuclk <= ~apuclk;

logic en;
assign en = (sys_addr & ~16'h001f) == 16'h4000;
assign sys_rdy = en ? 1'b1 : 1'bz;

logic [7:0] sel;
demux #(.N(3)) demux0 (.oe(en), .sel(sys_addr[4:2]), .q(sel));

// Registers

logic we;
logic [7:0] regs[4];
apu_registers r0 (.sel(sel[5]), .*);

// Audio channels

logic [3:0] pulse[2];
logic pulse_en[2], pulse_act[2];
apu_pulse #(.defect(1'b1)) p0 (.sel(sel[0]), .en(pulse_en[0]), .act(pulse_act[0]), .out(pulse[0]), .*);
apu_pulse p1 (.sel(sel[1]), .en(pulse_en[1]), .act(pulse_act[1]), .out(pulse[1]), .*);

logic [3:0] triangle;
logic triangle_en, triangle_act;
apu_triangle t0 (.sel(sel[2]), .en(triangle_en), .act(triangle_act), .out(triangle), .*);

logic [3:0] noise;
logic noise_en, noise_act;
apu_noise n0 (.sel(sel[3]), .en(noise_en), .act(noise_act), .out(noise), .*);

logic [6:0] dmc;
logic dmc_en, dmc_act, dmc_irq;
apu_dmc d0 (.sel(sel[4]), .en(dmc_en), .act(dmc_act), .out(dmc), .irq(dmc_irq),
	.start(we && sys_addr[1:0] == 2'h1), .*);

logic [7:0] mix;
apu_mixer mix0 (.out(mix), .*);
assign out = mix;

// Frame counter

logic frame_mode, frame_int_inhibit, frame_int;
assign frame_mode = regs[3][7], frame_int_inhibit = regs[3][6];

logic frame_quarter, frame_half;
assign qframe = frame_mode ^ frame_quarter, hframe = frame_mode ^ frame_half;

logic frame_write;
flag_keeper flag0 (.n_reset(n_reset),
	.clk(clk), .flag(we && sys_addr[1:0] == 2'h3),
	.clk_s(apuclk), .clr(1'b1), .out(frame_write));

enum int unsigned {S0, S1, S2, S3, S4} state;

parameter logic [11:0] frame_load_lut[5] = '{12'd3727, 12'd3727, 12'd3728, 12'd3728, 12'd3725};
logic [11:0] frame_load;
always_comb
begin
	frame_load = frame_load_lut[0];
	if (~frame_write)
		case (state)
		S0:	frame_load = frame_load_lut[0];
		S1:	frame_load = frame_load_lut[1];
		S2:	frame_load = frame_load_lut[2];
		S3:	frame_load = frame_load_lut[3];
		S4:	frame_load = frame_load_lut[4];
		endcase
end

logic [11:0] frame_cnt;
apu_timer #(.N(12)) ft0 (
	.clk(~apuclk), .n_reset(n_reset), .clkout(),
	.reload(frame_write), .loop(1'b1), .load(frame_load), .cnt(frame_cnt));

logic frame_reload;
assign frame_reload = frame_cnt == 12'h0;

always_ff @(negedge apuclk, negedge n_reset)
	if (~n_reset)
		state <= S0;
	else if (frame_write)
		state <= S0;
	else if (frame_reload)
		case (state)
		S0:	state <= S1;
		S1:	state <= S2;
		S2:	state <= S3;
		S3:	state <= frame_mode ? S4 : S0;
		S4:	state <= S0;
		default:	state <= S0;
		endcase

always_ff @(negedge apuclk, negedge n_reset)
	if (~n_reset) begin
		frame_quarter <= 1'b0;
		frame_half <= 1'b0;
	end else if (~frame_write && frame_reload) begin
		frame_quarter <= !(state == S3 && frame_mode);
		case (state)
		S1:	frame_half <= 1'b1;
		S3:	frame_half <= ~frame_mode;
		S4:	frame_half <= 1'b1;
		default:	frame_half <= 1'b0;
		endcase
	end else begin
		frame_quarter <= 1'b0;
		frame_half <= 1'b0;
	end

// Status register

assign {dmc_en, noise_en, triangle_en, pulse_en[1], pulse_en[0]} = regs[1][4:0];

logic stat_read;
assign stat_read = ~sys_rw && sel[5] && sys_addr[1:0] == 2'h1;
logic [7:0] stat_out;
assign stat_out = {dmc_irq, frame_int, 1'b0, dmc_act, noise_act, triangle_act, pulse_act[1], pulse_act[0]};
assign sys_data = stat_read ? stat_out : 8'bz;

// IRQ control

logic int_irq;
assign int_irq = frame_reload && state == S3;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		frame_int <= 1'b0;
	else if (~frame_mode && ~frame_int_inhibit && int_irq)
		frame_int <= 1'b1;
	else if (frame_int_inhibit | stat_read)
		frame_int <= 1'b0;

assign irq = ~(frame_int | dmc_irq);

endmodule
