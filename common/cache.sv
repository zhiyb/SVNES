module cache (
	input logic n_reset, clk,
	input logic we, req,
	output logic miss, rdy, swap,
	input logic [23:0] addr,
	input logic [15:0] data_in,
	output logic [15:0] data_out,
	
	output logic [23:0] if_addr_out,
	output logic [15:0] if_data_out,
	output logic if_we, if_req,
	input logic if_rdy,
	
	input logic [23:0] if_addr_in,
	input logic [15:0] if_data_in,
	input logic if_rdy_in
);

// Notes:
// If a cache line is pending, do not overwrite it
// Type: Write through with no write allocation

// Non-blocking arbiter swap control
// swap = 0: Lookup; swap = 1: Update
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset)
		swap <= 1'b0;
	else if (req)
		swap <= ~swap;
	else
		swap <= 1'b0;

// RAM, data format: valid(1), pending(1), tag(14), data(4x16)
logic [7:0] ram_addr_a, ram_addr_b;
logic [9:0] ram_be_a, ram_be_b;
logic [79:0] ram_data_a, ram_data_b;
logic ram_we_a, ram_we_b;
logic [79:0] ram_out_a, ram_out_b;
ramdual256x80 ram0 (.aclr(~n_reset), .clock(clk),
	.address_a(ram_addr_a), .address_b(ram_addr_b),
	.byteena_a(ram_be_a), .byteena_b(ram_be_b),
	.data_a(ram_data_a), .data_b(ram_data_b),
	.wren_a(ram_we_a), .wren_b(ram_we_b),
	.q_a(ram_out_a), .q_b(ram_out_b));

// RAM initialiser
logic init_busy;
logic [7:0] init_addr;
always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		init_busy <= 1'b1;
		init_addr <= 8'h0;
	end else if (init_addr == 8'hff) begin
		init_busy <= 1'b0;
	end else
		init_addr <= init_addr + 8'h1;

// Separate tag and index from address
logic [13:0] tag, if_tag;
logic [7:0] index, if_index;
logic [1:0] word, if_word;
assign {tag, index, word} = addr;
assign {if_tag, if_index, if_word} = if_addr_in;
logic [3:0] wordsel, if_wordsel;
assign wordsel = 2 ** word;
assign if_wordsel = 2 ** if_word;

// RAM interface A: access bus
assign ram_addr_a = index;
logic [4:0] be_a = {1'b1, wordsel};
assign {ram_be_a[8], ram_be_a[6], ram_be_a[4], ram_be_a[2], ram_be_a[0]} = be_a;
assign {ram_be_a[9], ram_be_a[7], ram_be_a[5], ram_be_a[3], ram_be_a[1]} = be_a;
assign ram_data_a = {we, ~we, tag, data_in, data_in, data_in, data_in};
assign ram_we_a = if_req;
logic ram_valid, ram_pend;
logic [13:0] ram_tag;
logic [15:0] ram_data;
assign {ram_valid, ram_pend, ram_tag} = ram_out_a[79:64];

always_comb
begin
	ram_data = ram_out_a[15:0];
	case (word)
	2'b00: ram_data = ram_out_a[15:0];
	2'b01: ram_data = ram_out_a[31:16];
	2'b10: ram_data = ram_out_a[47:32];
	2'b11: ram_data = ram_out_a[63:48];
	endcase
end

// RAM interface B: interfacing
assign ram_addr_b = init_busy ? init_addr : if_index;
logic [4:0] be_b = {1'b1, if_wordsel};
assign {ram_be_b[8], ram_be_b[6], ram_be_b[4], ram_be_b[2], ram_be_b[0]} = be_b;
assign {ram_be_b[9], ram_be_b[7], ram_be_b[5], ram_be_b[3], ram_be_b[1]} = be_b;
assign ram_data_b = {~init_busy & if_wordsel[3], ~if_wordsel[3], if_tag, if_data_in, if_data_in, if_data_in, if_data_in};
assign ram_we_b = init_busy | if_rdy_in;

// Output logic
assign if_addr_out = addr;
assign if_data_out = data_in;
assign if_we = we;
assign data_out = ram_data;

always_comb
begin
	miss = ~ram_valid || ram_tag != tag;
	if_req = ~init_busy & swap & if_rdy & req & ~ram_pend & (we | miss);
	rdy = ~init_busy & (~req | (swap & (we ? if_req : ~miss)));
end

endmodule
