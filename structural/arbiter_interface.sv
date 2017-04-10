interface arbiter_if #(parameter AN, DN, N);
	logic [AN - 1:0] addr;
	logic [DN - 1:0] data, mem;
	logic [N - 1:0] id;
	logic req, wr, ack, valid;
endinterface
