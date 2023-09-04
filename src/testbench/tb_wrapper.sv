module TB_WRAPPER;

initial
    #20ms $finish(0);

logic clk_50;
initial begin
    clk_50 = 0;
    forever #5ns clk_50 = ~clk_50;
end

logic reset_50;
initial begin
    reset_50 = 0;
    reset_50 = 1;
    @(posedge clk_50);
    reset_50 = 0;
end

wire  [15:0] DRAM_DQ;
logic [12:0] DRAM_ADDR;
logic [1:0]  DRAM_BA, DRAM_DQM;
wire         DRAM_CLK;
logic        DRAM_CKE;
logic        DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N;

WRAPPER w0 (
    .CLOCK_50       (clk_50),
    .KEY            ({2{~reset_50}}),
    .SW             (4'b0),
    .LED            (),

    .DRAM_ADDR      (DRAM_ADDR),
    .DRAM_BA        (DRAM_BA),
    .DRAM_DQM       (DRAM_DQM),
    .DRAM_CKE       (DRAM_CKE),
    .DRAM_CLK       (DRAM_CLK),
    .DRAM_CS_N      (DRAM_CS_N),
    .DRAM_RAS_N     (DRAM_RAS_N),
    .DRAM_CAS_N     (DRAM_CAS_N),
    .DRAM_WE_N      (DRAM_WE_N),
    .DRAM_DQ        (DRAM_DQ),

    .I2C_SCLK       (),
    .I2C_SDAT       (),

    .G_SENSOR_CS_N  (),
    .G_SENSOR_INT   (),

    .ADC_CS_N       (),
    .ADC_SADDR      (),
    .ADC_SCLK       (),
    .ADC_SDAT       (),

    .GPIO_0         (),
    .GPIO_0_IN      (),
    .GPIO_1         (),
    .GPIO_1_IN      (),
    .GPIO_2         (),
    .GPIO_2_IN      ()
);

SIM_SDRAM #(
) sim_sdram (
    .DRAM_DQ    (DRAM_DQ),
    .DRAM_ADDR  (DRAM_ADDR),
    .DRAM_BA    (DRAM_BA),
    .DRAM_DQM   (DRAM_DQM),
    .DRAM_CLK   (DRAM_CLK),
    .DRAM_CKE   (DRAM_CKE),
    .DRAM_CS_N  (DRAM_CS_N),
    .DRAM_RAS_N (DRAM_RAS_N),
    .DRAM_CAS_N (DRAM_CAS_N),
    .DRAM_WE_N  (DRAM_WE_N)
);

endmodule
