module TB;

logic CLK;

initial
begin
    CLK = 0;
    forever #5ns CLK = ~CLK;
end

endmodule
