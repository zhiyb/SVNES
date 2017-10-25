module apu_dmc (
	input logic clk, dclk, n_reset,

	input logic [15:0] sys_addr,
	inout wire [7:0] sys_data,
	output wire sys_rdy,
	input logic sys_rw,

	input logic bus_rdy,
	output logic bus_req,
	output wire [15:0] bus_addr,
	
	input logic apuclk, qframe, hframe,
	input logic sel, en, start,
	output logic act, irq,
	output logic [6:0] out
);

// Registers

logic we;
logic [7:0] regs[4];
apu_registers r0 (.*);

// Separation of register fields

logic irq_en;
assign irq_en = regs[0][7];

logic loop;
assign loop = regs[0][6];

logic [3:0] rate_load_reg;
assign rate_load_reg = regs[0][3:0];

logic [6:0] load_reg;
assign load_reg = regs[1][6:0];

logic [14:0] addr_load_reg;
assign addr_load_reg = {2'b11, regs[2], 6'h0};

logic [11:0] len_load_reg;
assign len_load_reg = {regs[3], 4'h1};

// Memory reader

logic [14:0] addr;
logic [11:0] len;
logic mr_req;

assign bus_req = en && mr_req && (len != 12'h0 || loop || start);
assign bus_addr = bus_rdy ? {1'b1, addr} : 16'bz;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		addr <= 15'h0;
		len <= 12'h0;
	end else if (~en) begin
		addr <= 15'h0;
		len <= 12'h0;
	end else if (bus_rdy) begin
		addr <= addr + 15'h1;
		len <= len - 12'h1;
	end else if (mr_req && len == 12'h0 && (loop || start)) begin
		addr <= addr_load_reg;
		len <= len_load_reg;
	end

logic [7:0] sample;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		sample <= 8'h0;
	else if (bus_rdy)
		sample <= sys_data;

assign act = len != 12'h0;
assign irq = ~en && irq_en && ~loop && len == 12'h0;

// Timer

logic [7:0] timer_load;
apu_rom_dmc_ntsc rom0 (.aclr(~n_reset), .clock(dclk), .address(rate_load_reg), .q(timer_load));

logic timer_clk;
logic [7:0] timer_cnt;
apu_timer #(.N(8)) t0 (
	.clk(apuclk), .n_reset(n_reset), .clkout(timer_clk),
	.reload(1'b0), .loop(1'b1), .load(timer_load), .cnt(timer_cnt));

// Shift register

logic [2:0] rem;
always_ff @(negedge timer_clk, negedge n_reset)
	if (~n_reset)
		rem <= 3'h0;
	else
		rem <= rem - 3'h1;

logic [7:0] shift;
always_ff @(negedge timer_clk, negedge n_reset)
	if (~n_reset)
		shift <= 8'h0;
	else if (rem == 3'h0)
		shift <= sample;
	else
		shift <= {1'b0, shift[7:1]};

logic shift_req;
flag_detector swp_flag1 (.clk(clk), .n_reset(n_reset), .flag(rem == 3'h0), .out(shift_req));

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		mr_req <= 1'b1;
	else if (bus_rdy)
		mr_req <= 1'b0;
	else if (shift_req)
		mr_req <= 1'b1;

logic playing;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		playing <= 1'b0;
	else if (rem == 3'h0 && timer_clk)
		playing <= ~mr_req;

// Output level

logic sub;
assign sub = ~shift[0];
logic [7:0] target;
assign target = out + ({7{sub}} ^ 7'h2) + {6'h0, sub};
logic target_ovf;
assign target_ovf = target[7] ^ sub;

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		out <= 7'b0;
	else if (playing & timer_clk & ~target_ovf)
		out <= target[6:0];
	else if (we && sys_addr[1:0] == 2'd1)
		out <= load_reg;

endmodule
