MEMORY {
	RAM1:	start = $0200, size = $0600;
	RAM2:	start = $6000, size = $2000;
	ROM1:	start = $8000, size = $8000, file = "%O";
}

SEGMENTS {
	CODE:	load = ROM1, type = ro;
	RODATA:	load = ROM1, type = ro;
	DMC:	load = ROM1, type = ro, align = 64;
	DATA:	load = ROM1, run = RAM2, type = rw, define = yes;
	BSS:	load = RAM2, type = bss, define = yes;
	VECT:	load = ROM1, type = ro, start = $fffa;
}
