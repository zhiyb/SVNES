module cache (
	input logic n_reset, clk,
	input logic we, req,
	output logic miss, rdy,
	input logic [23:0] addr,
	inout wire [15:0] data,
	
	output logic [23:0] if_addr_out,
	output logic [15:0] if_data_out,
	output logic if_we, if_req,
	input logic if_rdy,
	
	input logic [23:0] if_addr_in,
	input logic [15:0] if_data_in,
	input logic if_rdy_in
);

// RAM, data format: valid(1), fetch(1), tag(14), data(16)
logic [9:0] ram_addr_a, ram_addr_b;
logic [3:0] ram_be_a, ram_be_b;
logic [31:0] ram_data_a, ram_data_b;
logic ram_we_a, ram_we_b;
logic [31:0] ram_out_a, ram_out_b;
ramdual1kx32 ram0 (.aclr(~n_reset), .clock(~clk),
	.address_a(ram_addr_a), .address_b(ram_addr_b),
	.byteena_a(ram_be_a), .byteena_b(ram_be_b),
	.data_a(ram_data_a), .data_b(ram_data_b),
	.wren_a(ram_we_a), .wren_b(ram_we_b),
	.q_a(ram_out_a), .q_b(ram_out_b));

logic [15:0] data_out;
assign data = we ? 16'bz : data_out;

// Separate tag and index from address
logic [13:0] tag, if_tag;
logic [9:0] index, if_index;
assign {tag, index} = addr;
assign {if_tag, if_index} = if_addr_in;

// RAM interface A: access bus
assign ram_addr_a = index;
assign ram_be_a = 4'b1111;
assign ram_data_a = {we, 1'b1, tag, data};
assign ram_we_a = if_req;
logic ram_valid, ram_fetch;
logic [13:0] ram_tag;
logic [15:0] ram_data;
assign {ram_valid, ram_fetch, ram_tag, ram_data} = ram_out_a;

// RAM interface B: interfacing
assign ram_addr_b = if_index;
assign ram_be_b = 4'b1111;
assign ram_data_b = {1'b1, 1'b0, if_tag, if_data_in};
assign ram_we_b = if_rdy_in && !(ram_we_a && ram_addr_a == ram_addr_b);

// Output logic
always_comb
begin
	miss = ~ram_valid || ram_tag != tag;
	data_out = ram_data;
	if_addr_out = addr;
	if_data_out = data;
	if_we = we;
	if_req = if_rdy & req & miss & ~ram_fetch;
	rdy = ~miss;
end

endmodule
