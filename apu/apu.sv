`include "config.h"
import typepkg::*;

module apu (
	sys_if sys,
	sysbus_if sysbus,
	output logic irq, dbg,
	output logic [7:0] out
);

logic apuclk, qframe, hframe;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		apuclk <= 1'b0;
	else
		apuclk <= ~apuclk;

counter #(.n($clog2(894886) - 1)) c0 (.clk(apuclk), .n_reset(sys.n_reset), .top(894886), .out(dbg));

logic en;
assign en = (sysbus.addr & ~(`APU_SIZE - 1)) == `APU_BASE;
assign sysbus.rdy = en ? 1'b1 : 1'bz;

logic [7:0] sel;
demux #(.N(3)) d0 (.oe(en), .sel(sysbus.addr[4:2]), .q(sel));

logic [3:0] pulse[2];
logic pulse_en[2], pulse_act[2];
apu_pulse p0 (.sel(sel[0]), .en(pulse_en[0]), .act(pulse_act[0]), .out(pulse[0]), .*);
apu_pulse p1 (.sel(sel[1]), .en(pulse_en[1]), .act(pulse_act[1]), .out(pulse[1]), .*);

logic [3:0] triangle;
logic triangle_en, triangle_act;
assign triangle = 4'b0;
assign triangle_stat = 1'b0;
assign triangle_act = 1'b0;

logic [3:0] noise;
logic noise_en, noise_act;
assign noise = 4'b0;
assign noise_stat = 1'b0;
assign noise_act = 1'b0;

logic [6:0] dmc;
logic dmc_en, dmc_act, dmc_int;
assign dmc = 7'b0;
assign dmc_stat = 1'b0;
assign dmc_act = 1'b0;
assign dmc_int = 1'b0;

logic [7:0] mix;
apu_mixer mix0 (.out(mix), .*);
assign out = mix;

// Frame counter

logic frame_int;
assign irq = ~frame_int;

logic frame_mode, frame_int_inhibit;

logic frame_write;
assign frame_write = sysbus.we && sel[5] && sysbus.addr[1:0] == 2'h3;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		frame_mode <= 1'b0;
		frame_int_inhibit <= 1'b0;
	end else if (frame_write) begin
		frame_mode <= sysbus.data[7];
		frame_int_inhibit <= sysbus.data[6];
	end

logic frame_write_sys, frame_write_apu;
always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		frame_write_sys <= 1'b0;
	else if (frame_write)
		frame_write_sys <= 1'b1;
	else if (frame_write_apu)
		frame_write_sys <= 1'b0;

always_ff @(posedge apuclk, negedge sys.n_reset)
	if (~sys.n_reset)
		frame_write_apu <= 1'b0;
	else
		frame_write_apu <= frame_write_sys;

logic frame_quarter, frame_half;
assign qframe = frame_mode ^ frame_quarter, hframe = frame_mode ^ frame_half;

parameter logic [11:0] frame_load[5] = '{
	12'h3727, 12'h3727, 12'h3728, 12'h3728, 12'h3725
	//12'h6, 12'h5, 12'h4, 12'h3, 12'h2
};

enum int unsigned {S0, S1, S2, S3, S4} state;

logic [11:0] frame_cnt;

always_ff @(negedge apuclk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		frame_quarter <= 1'b0;
		frame_half <= 1'b0;
		frame_cnt <= 12'b0;
		state <= S0;
	end else if (frame_write_apu) begin
		frame_quarter <= 1'b0;
		frame_half <= 1'b0;
		frame_cnt <= frame_load[0];
		state <= S1;
	end else if (frame_cnt == 12'b0)
		case (state)
		S0:	begin	// 0
			frame_cnt <= frame_load[0];
			state <= S1;
			frame_quarter <= 1'b1;
		end
		S1:	begin	// 3728
			frame_cnt <= frame_load[1];
			state <= S2;
			frame_quarter <= 1'b1;
			frame_half <= 1'b1;
		end
		S2:	begin	// 7456
			frame_cnt <= frame_load[2];
			state <= S3;
			frame_quarter <= 1'b1;
		end
		S3:	begin	// 11185
			frame_cnt <= frame_load[3];
			if (frame_mode)
				state <= S4;
			else begin
				state <= S0;
				frame_quarter <= 1'b1;
				frame_half <= 1'b1;
			end
		end
		S4:	begin	// 14914
			frame_cnt <= frame_load[4];
			state <= S0;
			frame_quarter <= 1'b1;
			frame_half <= 1'b1;
		end
		default: begin
			frame_quarter <= 1'b0;
			frame_half <= 1'b0;
			frame_cnt <= 12'b0;
			state <= S0;
		end
		endcase
	else begin
		frame_cnt <= frame_cnt - 12'b1;
		frame_quarter <= 1'b0;
		frame_half <= 1'b0;
	end

// Status register

dataLogic stat_out;
assign stat_out = {dmc_int, frame_int, 1'b0,
	dmc_act, noise_act, triangle_act, pulse_act[1], pulse_act[0]};

logic stat_read;
assign stat_read = ~sysbus.we && sel[5] && sysbus.addr[1:0] == 2'h1;
assign sysbus.data = stat_read ? stat_out : {`DATA_N{1'bz}};

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		pulse_en[0] <= 1'b0;
		pulse_en[1] <= 1'b0;
		triangle_en <= 1'b0;
		noise_en <= 1'b0;
		dmc_en <= 1'b0;
	end else if (sysbus.we && sel[5]) begin
		if (sysbus.addr[1:0] == 2'h1) begin
			pulse_en[0] <= sysbus.data[0];
			pulse_en[1] <= sysbus.data[1];
			triangle_en <= sysbus.data[2];
			noise_en <= sysbus.data[3];
			dmc_en <= sysbus.data[4];
		end
	end

// IRQ control

logic int_set;
assign int_set = ~frame_mode && ~frame_int_inhibit && frame_cnt == 12'b0 && state == S3;

logic int_clr;
assign int_clr = frame_int_inhibit | stat_read;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		frame_int <= 1'b0;
	else if (int_set)
		frame_int <= 1'b1;
	else if (int_clr)
		frame_int <= 1'b0;

endmodule
