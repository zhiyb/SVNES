/*** Common definitions ***/
`define WRITE	0
`define READ	1

`define TX	0
`define RX	1

/*** Architecture configuration ***/
`define ADDR_N			16
`define PERIPHBUS_N	8
`define PERIPH_N		3
`define DATA_N			8

/*** SPI peripheral registers ***/
`define SPI_CTRL			0
`define SPI_CTRL_EN		8'b01000000
`define SPI_CTRL_CPOL	8'b00100000
`define SPI_CTRL_CPHA	8'b00010000
`define SPI_CTRL_PR		8'b00000111
`define SPI_CTRL_MASK	(`SPI_CTRL_EN | `SPI_CTRL_CPOL | `SPI_CTRL_CPHA | `SPI_CTRL_PR)
`define SPI_STAT			1
`define SPI_STAT_FLAG	8'b10000000
`define SPI_STAT_MASK	(`SPI_STAT_FLAG)
`define SPI_DATA			2
