package sdram_types;

typedef enum logic [4:0] {NOP, MRS, PALL, REF,
	ACT, PRE, READ, READA, WRITE, WRITEA} cmd_t;

typedef struct packed {
	cmd_t cmd;
	logic [1:0] ba;
	struct packed {
		logic [8:0] column;
		logic [15:0] data;
	} d;
} data_t;

endpackage
