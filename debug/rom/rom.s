; asmsyntax=asmM6502

	.include "common.inc"
	.include "render.inc"
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

loop:	; Render a string
	_CPA	r_s, #offset, 3
	_CPA	r_c, #test, 2
	_CPA	r_w, #str_hw, 2
	jsr	render_string

	; Render a number as hex
	_CPA	r_c, #white, 2
	lda	#$02
	jsr	render_hex

	_CPA	r_c, #red, 2
	lda	#$46
	jsr	render_hex

	_CPA	r_c, #green, 2
	lda	#$8a
	jsr	render_hex

	_CPA	r_c, #blue, 2
	lda	#$ce
	jsr	render_hex

	jmp	loop
.endproc

	.rodata
str_hw:	.byte	"Hello, world!", 0
