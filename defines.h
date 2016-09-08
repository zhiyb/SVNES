/*** Status register ***/
`define STATUS_N	7
`define STATUS_V	6
`define STATUS_R	5
`define STATUS_B	4
`define STATUS_D	3
`define STATUS_I	2
`define STATUS_Z	1
`define STATUS_C	0

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
