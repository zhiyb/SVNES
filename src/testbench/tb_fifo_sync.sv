module TB_FIFO_SYNC;

// Run for 1ms
initial
    #1ms $finish(0);

// 100MHz TB clock
localparam real FREQ = 100.0;

logic clk;
initial begin
    clk = 1;
    forever
        #(0.5/FREQ * 1us) clk = ~clk;
end

logic reset;
initial begin
    $urandom(0);    // Initialise random seed
    reset = 0;
    @(posedge clk);
    reset = 1;
    @(posedge clk);
    reset = 0;
end

typedef logic [15:0] data_t;

generate
begin: test_0

    data_t in_data;
    logic  in_req, in_ack;

    data_t out_data;
    logic  out_req, out_ack;

    FIFO_SYNC #(
        .WIDTH      ($bits(data_t)),
        .DEPTH_LOG2 (3)
    ) fifo0 (
        .CLK        (clk),
        .RESET_IN   (reset),

        .IN_DATA    (in_data),
        .IN_REQ     (in_req),
        .IN_ACK     (in_ack),

        .OUT_DATA   (out_data),
        .OUT_REQ    (out_req),
        .OUT_ACK    (out_ack)
    );

    // Input data generator
    always_ff @(posedge clk, posedge reset)
        if (reset)
            in_req <= 0;
        else
            in_req <= ($urandom % 100) < 50;

    always_ff @(posedge clk, posedge reset)
        if (reset)
            in_data <= 0;
        else if (in_req & in_ack)
            in_data <= in_data + 1;

    // Output data checker
    always_ff @(posedge clk, posedge reset)
        if (reset)
            out_ack <= 0;
        else
            out_ack <= ($urandom % 100) < 20;

    data_t out_check;

    always_ff @(posedge clk, posedge reset)
        if (reset) begin
            out_check <= 0;
        end else if (out_req & out_ack) begin
            out_check <= out_check + 1;
            assert (out_data == out_check)
            else $error("output mismatch");
        end

end: test_0

begin: test_1

    data_t in_data;
    logic  in_req, in_ack;

    data_t out_data;
    logic  out_req, out_ack;

    FIFO_SYNC #(
        .WIDTH      ($bits(data_t)),
        .DEPTH_LOG2 (3)
    ) fifo0 (
        .CLK        (clk),
        .RESET_IN   (reset),

        .IN_DATA    (in_data),
        .IN_REQ     (in_req),
        .IN_ACK     (in_ack),

        .OUT_DATA   (out_data),
        .OUT_REQ    (out_req),
        .OUT_ACK    (out_ack)
    );

    // Input data generator
    always_ff @(posedge clk, posedge reset)
        if (reset)
            in_req <= 0;
        else
            in_req <= ($urandom % 100) < 20;

    always_ff @(posedge clk, posedge reset)
        if (reset)
            in_data <= 0;
        else if (in_req & in_ack)
            in_data <= in_data + 1;

    // Output data checker
    always_ff @(posedge clk, posedge reset)
        if (reset)
            out_ack <= 0;
        else
            out_ack <= ($urandom % 100) < 50;

    data_t out_check;

    always_ff @(posedge clk, posedge reset)
        if (reset) begin
            out_check <= 0;
        end else if (out_req & out_ack) begin
            out_check <= out_check + 1;
            assert (out_data == out_check)
            else $error("output mismatch");
        end

end: test_1
endgenerate

endmodule
