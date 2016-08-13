/*** Common definitions ***/
`define WRITE	0
`define READ	1

`define TX	0
`define RX	1

/*** Architecture configuration ***/
`define BOOTROM_N		8
`define BOOTROM_SIZE	(2 ** `BOOTROM_N)
`define ADDR_N			16
`define PERIPHS_N		8
`define PERIPH_N		2
`define PERIPH_MAP_N	(`PERIPHS_N - `PERIPH_N)
`define IDATA_N		16
`define DATA_N			8

typedef logic [`BOOTROM_N : 0]		bootromLogic;
typedef logic [`ADDR_N : 0]			addrLogic;
typedef logic [`PERIPHS_N : 0]		periphsLogic;
typedef logic [`PERIPH_N - 1 : 0]	periphLogic;
typedef logic [`IDATA_N - 1 : 0]		idataLogic;
typedef logic [`DATA_N - 1 : 0]		dataLogic;

/*** Base addresses ***/
`define P_GPIO0	{{`PERIPH_MAP_N{1'b0}} + 0, `PERIPH_N'b0}
`define P_GPIO1	{{`PERIPH_MAP_N{1'b0}} + 1, `PERIPH_N'b0}
`define P_SPI0		{{`PERIPH_MAP_N{1'b0}} + 2, `PERIPH_N'b0}

/*** GPIO peripheral registers ***/
`define GPIO_DIR	0
`define GPIO_OUT	1
`define GPIO_IN	2

/*** SPI peripheral registers ***/
`define SPI_CTRL			0
`define SPI_CTRL_EN		8'b01000000
`define SPI_CTRL_CPOL	8'b00100000
`define SPI_CTRL_CPHA	8'b00010000
`define SPI_CTRL_PR		8'b00000111
`define SPI_CTRL_MASK	(`SPI_CTRL_EN | `SPI_CTRL_CPOL | `SPI_CTRL_CPHA | `SPI_CTRL_PR)
`define SPI_STAT			1
`define SPI_STAT_RXNE_	7
`define SPI_STAT_RXNE	(8'b1 << `SPI_STAT_RXNE_)
`define SPI_STAT_TXE_	6
`define SPI_STAT_TXE		(8'b1 << `SPI_STAT_TXE_)
`define SPI_STAT_MASK	(`SPI_STAT_RXNE | `SPI_STAT_TXE)
`define SPI_DATA			2
