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
loop:
	; Render background rectangle
	lda	#<offset
	sta	r_s
	lda	#>offset
	sta	r_s + 1
	lda	#offset >> 16
	sta	r_s + 2
	lda	#<background
	sta	r_c
	lda	#>background
	sta	r_c + 1
	lda	#<width
	sta	r_w
	lda	#>width
	sta	r_w + 1
	lda	#<height
	sta	r_h
	lda	#>height
	sta	r_h + 1
	jsr	render_rect

	lda	#<offset
	sta	r_s
	lda	#>offset
	sta	r_s + 1
	lda	#offset >> 16
	sta	r_s + 2
	lda	#<test
	sta	r_c
	lda	#>test
	sta	r_c + 1
	jsr	render_rect

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
