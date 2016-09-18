module cache #(parameter ADDRN = 24, N = 16,
	IFADDRN = 24, IFN = 16, SETN = 3, BSN = 0, WAYN = 1) (
	input logic n_reset, clk,
	input logic we, req,
	output logic miss, rdy,
	input logic [ADDRN - 1:0] addr,
	inout wire [N - 1:0] data,
	
	output logic [IFADDRN - 1:0] if_addr_out,
	output logic [IFN - 1:0] if_data_out,
	output logic if_we, if_req,
	input logic if_rdy,
	
	input logic [IFADDRN - 1:0] if_addr_in,
	input logic [IFN - 1:0] if_data_in,
	input logic if_rdy_in
);

logic [N - 1:0] data_out;
assign data = we ? {N{1'bz}} : data_out;

logic [IFADDRN - SETN - BSN - 1:0] tag, if_tag;
logic [SETN - 1:0] index, if_index;
//logic [$clog2((2 ** BSN) * IFN / N) - 1:0] sub;
//logic [BSN - 1:0] if_sub;
assign {tag, index/*, sub*/} = addr;
assign {if_tag, if_index/*, if_sub*/} = if_addr_in;

struct {
	struct {
		logic valid[2 ** BSN], fetch[2 ** BSN];
		logic [IFADDRN - SETN - BSN - 1:0] tag;
		logic [IFN * (2 ** BSN) - 1:0] data;
	} entry[2 ** WAYN];
	logic [WAYN - 1:0] way;
} set[2 ** SETN];

always_ff @(posedge clk, negedge n_reset)
	if (~n_reset) begin
		for (int i = 0; i < 2 ** SETN; i++) begin
			for (int j = 0; j < 2 ** WAYN; j++) begin
				set[i].entry[j].valid <= '{2 ** BSN{1'b0}};
				set[i].entry[j].fetch <= '{2 ** BSN{1'b0}};
				set[i].entry[j].tag <= {IFADDRN - SETN - BSN{1'b0}};
				set[i].entry[j].data <= {IFN * (2 ** BSN){1'b0}};
			end
			set[i].way <= {WAYN{1'b0}};
		end
	end else begin
		if (if_rdy_in) begin
			for (int i = 0; i < 2 ** WAYN; i++) begin
				if (set[if_index].entry[i].tag == if_tag) begin
					set[if_index].entry[i].valid <= '{2 ** BSN{1'b1}};
					set[if_index].entry[i].fetch <= '{2 ** BSN{1'b0}};
					set[if_index].entry[i].data <= if_data_in;
				end
			end
		end
		if (req && miss) begin
			set[index].entry[set[index].way].valid <= '{2 ** BSN{we}};
			set[index].entry[set[index].way].fetch <= '{2 ** BSN{1'b1}};
			set[index].entry[set[index].way].tag <= tag;
			set[index].way <= set[index].way + 'h1;
			if (we)
				set[index].entry[set[index].way].data <= data;
		end
	end

always_comb
begin
	miss = 1'b1;
	rdy = 1'b0;
	data_out = {N{1'b0}};
	if_addr_out = addr;
	if_data_out = data;
	if_we = we;
	if_req = 1'b0;
	
	if (req) begin
		if_req = 1'b1;
		for (int i = 0; i < 2 ** WAYN; i++) begin
			if (set[index].entry[i].tag == tag) begin
				if_req = ~set[index].entry[i].fetch[0];
				if (set[index].entry[i].valid[0] == 1'b1) begin
					miss = 1'b0;
					rdy = 1'b1;
					data_out = set[index].entry[i].data;
				end
			end
		end
	end
end

endmodule
