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
	_CPA	r_s, #offset, 3
	_CPA	r_c, #bg, 2
	_CPA	r_w, #width, 2
	_CPA	r_h, #height, 2
	jsr	render_rect

loop:	; Render a string
	_CPA	r_s, #offset, 3
	_CPA	r_c, #test, 2
	_CPA	r_w, #str_hw, 2
	jsr	render_string

	jmp	loop
.endproc

.proc	num16	; Convert a number {X} to a string {Y, X} (base 16)
	pha

	; Higher digit
	txa
	lsr
	lsr
	lsr
	lsr
	jsr	digit16
	tay

	; Lower digit
	txa
	and	#$0f
	jsr	digit16
	tax

	pla
	rts
.endproc

.proc	digit16	; Convert a single digit {A} to a character {A} (base 16)
	cmp	#$0a
	bmi	@mi
	clc
	adc	#('A' - $0a)
	rts
@mi:	clc
	adc	#('0')
	rts
.endproc

	.rodata
str_hw:	.byte	"Hello, world!", 0
