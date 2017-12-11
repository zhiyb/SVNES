; asmsyntax=asmM6502

	.bss
	.org	$6000

dbg_addr:	.dword	0
dbg_data:	.word	0
dbg_ctrl:	.byte	0
dbg_scan:	.byte	0

	.reloc

; Scan reset/load
.macro	dbg_load
	lda	#$ff
	sta	dbg_ctrl
.endmacro

; Scan transfer
.macro	dbg_scan
	sta	dbg_scan
:	bit	dbg_ctrl
	bmi	:-
	lda	dbg_scan
.endmacro
