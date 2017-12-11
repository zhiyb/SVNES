; asmsyntax=asmM6502

	.include "common.inc"
	.include "render.inc"
	.include "debug.inc"
	.reloc

	.segment "VECT"	; Interrupt vectors
	.word	0	; NMI
	.word	main	; Reset
	.word	0	; IRQ

	.code

.proc	main
	; Render background rectangle
	_CPA	r_s, #offset - margin * lsize - margin, 3
	_CPA	r_w, #width + margin * 2, 2
	_CPA	r_h, #height + margin * 2, 2
	_CPA	r_c, #bg, 2
	jsr	render_rect

loop:	dbg_load

	; Runtime
	_CPA	r_s, #offset, 3
	_CPA	r_c, #test, 2
	_CPA	r_w, #str_1, 2
	jsr	render_string

	_CPA	r_c, #green, 2
	lda	#$00
	dbg_scan
	jsr	render_hex

	; Memtest
	_CPA	r_c, #test, 2
	_CPA	r_w, #str_2, 2
	jsr	render_string

	_CPA	r_c, #red, 2
	lda	#$00
	dbg_scan
	jsr	render_hex

	jmp	loop
.endproc

	.rodata
str_1:
	.byte	"Runtime: ", 0
str_2:
	.byte	" s, memtest fail: ", 0
