MEMORY {
	RAM:	start = $0000, size = $0800, file = "%O";
}

SEGMENTS {
	ZEROPAGE:	load = RAM, type = rw, offset = $0;
	DATA:		load = RAM, type = rw, define = yes;
	BSS:		load = RAM, type = rw, define = yes;
	RODATA:		load = RAM, type = ro;
	CODE:		load = RAM, type = ro;
	VECT:		load = RAM, type = ro, offset = $07fa;
}
