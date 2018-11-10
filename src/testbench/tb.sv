module TB;

initial
    #1ms $finish(0);

logic CLK;

initial
begin
    CLK = 0;
    forever #5ns CLK = ~CLK;
end

endmodule
