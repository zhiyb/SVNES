`include "config.h"
import typepkg::*;

module apu (
	sys_if sys,
	sysbus_if sysbus,
	output logic [7:0] out
);

logic apuclk, qframe, hframe;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		apuclk <= 1'b0;
	else
		apuclk <= ~apuclk;

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

logic [3:0] noise;
logic noise_en, noise_act;
assign noise = 4'b0;
assign noise_stat = 1'b0;

logic [6:0] dmc;
logic dmc_en, dmc_act, dmc_int;
assign dmc = 7'b0;
assign dmc_stat = 1'b0;
assign dmc_int = 1'b0;

logic [7:0] mix;
apu_mixer mix0 (.out(mix), .*);
assign out = mix;

// Frame counter

logic frame_int;
assign frame_int = 1'b0;

logic frame_mode, frame_int_inhibit;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		frame_mode <= 1'b0;
		frame_int_inhibit <= 1'b0;
	end

logic frame_quarter, frame_half;
assign qframe = frame_mode ^ frame_quarter, hframe = frame_mode ^ frame_half;

// Status register

dataLogic stat_out;
assign stat_out = {dmc_int, frame_int, 1'b0,
	dmc_act, noise_act, triangle_act, pulse_act[1], pulse_act[0]};

logic stat_read;
assign stat_read = ~sysbus.we && sel[5] && sysbus.addr[1] == 2'h1;
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

endmodule
