module TB_FIFO_ASYNC;

// Run for 1ms
initial
    #1ms $finish(0);

// 100MHz TB clock 1
localparam real FREQ_1 = 100.0;

logic clk_1;
initial begin
    clk_1 = 0;
    forever
        #(0.5/FREQ_1 * 1us) clk_1 = ~clk_1;
end

logic reset_1;
initial begin
    reset_1 = 0;
    reset_1 = 1;
    @(posedge clk_1);
    @(posedge clk_1);
    reset_1 = 0;
end

// 80MHz TB clock 2
localparam real FREQ_2 = 80.0;

logic clk_2;
initial begin
    clk_2 = 0;
    forever
        #(0.5/FREQ_2 * 1us) clk_2 = ~clk_2;
end

logic reset_2;
initial begin
    reset_2 = 0;
    reset_2 = 1;
    @(posedge clk_2);
    @(posedge clk_2);
    reset_2 = 0;
end

// Initialise random seed
initial begin
    $urandom(0);
end



typedef logic [15:0] data_t;

generate
begin: test_00

    data_t in_data;
    logic  in_req, in_ack;

    data_t out_data;
    logic  out_req, out_ack;

    FIFO_ASYNC #(
        .WIDTH  ($bits(data_t))
    ) fifo (
        .WRITE_CLK      (clk_1),
        .WRITE_RESET_IN (reset_1),
        .WRITE_DATA_IN  (in_data),
        .WRITE_REQ_IN   (in_req),
        .WRITE_ACK_OUT  (in_ack),

        .READ_CLK       (clk_2),
        .READ_RESET_IN  (reset_2),
        .READ_DATA_OUT  (out_data),
        .READ_REQ_OUT   (out_req),
        .READ_ACK_IN    (out_ack)
    );

    // Input data generator
    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1)
            in_req <= 0;
        else
            in_req <= ($urandom % 100) < 50;

    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1)
            in_data <= 0;
        else if (in_req & in_ack)
            in_data <= in_data + 1;

    // Output data checker
    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2)
            out_ack <= 0;
        else
            out_ack <= ($urandom % 100) < 20;

    data_t out_check;

    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2) begin
            out_check <= 0;
        end else if (out_req & out_ack) begin
            out_check <= out_check + 1;
            assert (out_data == out_check)
            else $error("output mismatch");
        end

end: test_00

begin: test_01

    data_t in_data;
    logic  in_req, in_ack;

    data_t out_data;
    logic  out_req, out_ack;

    FIFO_ASYNC #(
        .WIDTH  ($bits(data_t))
    ) fifo (
        .WRITE_CLK      (clk_1),
        .WRITE_RESET_IN (reset_1),
        .WRITE_DATA_IN  (in_data),
        .WRITE_REQ_IN   (in_req),
        .WRITE_ACK_OUT  (in_ack),

        .READ_CLK       (clk_2),
        .READ_RESET_IN  (reset_2),
        .READ_DATA_OUT  (out_data),
        .READ_REQ_OUT   (out_req),
        .READ_ACK_IN    (out_ack)
    );

    // Input data generator
    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1)
            in_req <= 0;
        else
            in_req <= ($urandom % 100) < 20;

    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1)
            in_data <= 0;
        else if (in_req & in_ack)
            in_data <= in_data + 1;

    // Output data checker
    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2)
            out_ack <= 0;
        else
            out_ack <= ($urandom % 100) < 50;

    data_t out_check;

    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2) begin
            out_check <= 0;
        end else if (out_req & out_ack) begin
            out_check <= out_check + 1;
            assert (out_data == out_check)
            else $error("output mismatch");
        end

end: test_01

begin: test_10

    data_t in_data;
    logic  in_req, in_ack;

    data_t out_data;
    logic  out_req, out_ack;

    FIFO_ASYNC #(
        .WIDTH  ($bits(data_t))
    ) fifo (
        .WRITE_CLK      (clk_2),
        .WRITE_RESET_IN (reset_2),
        .WRITE_DATA_IN  (in_data),
        .WRITE_REQ_IN   (in_req),
        .WRITE_ACK_OUT  (in_ack),

        .READ_CLK       (clk_1),
        .READ_RESET_IN  (reset_1),
        .READ_DATA_OUT  (out_data),
        .READ_REQ_OUT   (out_req),
        .READ_ACK_IN    (out_ack)
    );

    // Input data generator
    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2)
            in_req <= 0;
        else
            in_req <= ($urandom % 100) < 50;

    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2)
            in_data <= 0;
        else if (in_req & in_ack)
            in_data <= in_data + 1;

    // Output data checker
    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1)
            out_ack <= 0;
        else
            out_ack <= ($urandom % 100) < 20;

    data_t out_check;

    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1) begin
            out_check <= 0;
        end else if (out_req & out_ack) begin
            out_check <= out_check + 1;
            assert (out_data == out_check)
            else $error("output mismatch");
        end

end: test_10

begin: test_11

    data_t in_data;
    logic  in_req, in_ack;

    data_t out_data;
    logic  out_req, out_ack;

    FIFO_ASYNC #(
        .WIDTH  ($bits(data_t))
    ) fifo (
        .WRITE_CLK      (clk_2),
        .WRITE_RESET_IN (reset_2),
        .WRITE_DATA_IN  (in_data),
        .WRITE_REQ_IN   (in_req),
        .WRITE_ACK_OUT  (in_ack),

        .READ_CLK       (clk_1),
        .READ_RESET_IN  (reset_1),
        .READ_DATA_OUT  (out_data),
        .READ_REQ_OUT   (out_req),
        .READ_ACK_IN    (out_ack)
    );

    // Input data generator
    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2)
            in_req <= 0;
        else
            in_req <= ($urandom % 100) < 20;

    always_ff @(posedge clk_2, posedge reset_2)
        if (reset_2)
            in_data <= 0;
        else if (in_req & in_ack)
            in_data <= in_data + 1;

    // Output data checker
    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1)
            out_ack <= 0;
        else
            out_ack <= ($urandom % 100) < 50;

    data_t out_check;

    always_ff @(posedge clk_1, posedge reset_1)
        if (reset_1) begin
            out_check <= 0;
        end else if (out_req & out_ack) begin
            out_check <= out_check + 1;
            assert (out_data == out_check)
            else $error("output mismatch");
        end

end: test_11
endgenerate

endmodule
