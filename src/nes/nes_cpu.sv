module NES_CPU #(
    parameter string BOOTROM
) (
    input  wire         CLK,
    input  wire         RESET_IN,
    input  logic        CLK_ENABLE_IN,

    // Interrupts
    input  logic        INT_RESET_IN,
    input  logic        INT_NMI_IN,
    input  logic        INT_IRQ_IN,

    // External bus
    output logic [15:0] ADDR_OUT,
    output logic        READ_ENABLE_OUT,
    input  logic [7:0]  READ_DATA_IN,
    output logic        WRITE_ENABLE_OUT,
    output logic [7:0]  WRITE_DATA_OUT
);

// Use initialised internal RAM as bootrom
logic bootrom_mode;
assign bootrom_mode = '1;

// CPU system bus
typedef logic [15:0] addr_t;
typedef logic [7:0]  data_t;
addr_t sys_addr;
data_t sys_read_data, sys_write_data;
logic  sys_read, sys_write;

// External bus
logic ext_sel;
assign ext_sel          = !bootrom_mode && sys_addr >= 'h2000;
assign ADDR_OUT         = sys_addr;
assign READ_ENABLE_OUT  = ext_sel & sys_read;
assign WRITE_ENABLE_OUT = ext_sel & sys_write;
assign WRITE_DATA_OUT   = sys_write_data;

logic ext_out;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        ext_out <= 0;
    else if (ext_sel & sys_read)
        ext_out <= 1;
    else if (CLK_ENABLE_IN)
        ext_out <= 0;

// Internal 2KiB RAM @ 0x0000 + 0x2000
logic ram_sel;
assign ram_sel = bootrom_mode || sys_addr <= 'h1fff;

logic ram_out;
always_ff @(posedge CLK, posedge RESET_IN)
    if (RESET_IN)
        ram_out <= 0;
    else if (ram_sel & sys_read)
        ram_out <= 1;
    else if (CLK_ENABLE_IN)
        ram_out <= 0;

data_t ram_read_data;
RAM_SP #(
    .WIDTH (8),
    .DEPTH ('h800),
    .INIT  (BOOTROM)
) ram (
    .CLK             (CLK),
    .RESET_IN        (RESET_IN),
    .ADDR_IN         (sys_addr[10:0]),
    .READ_ENABLE_IN  (ram_sel & sys_read),
    .READ_DATA_OUT   (ram_read_data),
    .WRITE_ENABLE_IN (ram_sel & sys_write),
    .WRITE_DATA_IN   (sys_write_data)
);

// Read data mux
always_comb begin
    sys_read_data = 0;
    if (ram_out)
        sys_read_data |= ram_read_data;
    if (ext_out)
        sys_read_data |= READ_DATA_IN;
end

// 6502 CPU
C6502 cpu (
    .CLK              (CLK),
    .RESET_IN         (RESET_IN),
    .CLK_ENABLE_IN    (CLK_ENABLE_IN),

    .INT_RESET_IN     (INT_RESET_IN),
    .INT_NMI_IN       (INT_NMI_IN),
    .INT_IRQ_IN       (INT_IRQ_IN),

    .ADDR_OUT         (sys_addr),
    .READ_ENABLE_OUT  (sys_read),
    .READ_DATA_IN     (sys_read_data),
    .WRITE_ENABLE_OUT (sys_write),
    .WRITE_DATA_OUT   (sys_write_data)
);

endmodule
