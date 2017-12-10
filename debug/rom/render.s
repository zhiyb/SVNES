; asmsyntax=asmM6502

	.include "common.inc"
	.include "debug.inc"
	.import ascii
	.reloc

	.zeropage
	.exportzp	r_s, r_c, r_w, r_h
r_s:	.dword	0
r_c:	.word	0
r_w:	.word	0
r_h:	.word	0
cntx:	.word	0
cnty:	.word	0

	.code

	.export	render_dots
.proc	render_dots
	pha
	lda	r_w + 1
	sta	cntx + 1
	lda	r_w + 0
	sta	cntx + 0
	; Check if cntx == 0
	bne	start
	lda	cntx + 1
	beq	ret
start:	; Set start address
	lda	r_s + 2
	sta	dbg_addr + 2
	lda	r_s + 1
	sta	dbg_addr + 1
	lda	r_s + 0
	sta	dbg_addr + 0
	lda	r_c + 1
	sta	dbg_data + 1
next:	; Draw point
	lda	r_c + 0
	sta	dbg_data + 0
	dec	cntx
	bne	next
	; Check if >cntx == 0
	lda	cntx + 1
	beq	ret
	dec	cntx + 1
	jmp	next
ret:	; Finished, return
	pla
	rts
.endproc

	.export	render_rect
.proc	render_rect
	pha
	lda	r_h + 1
	sta	cnty + 1
	lda	r_h + 0
	sta	cnty + 0
	; Check if cnty == 0
	bne	next
	lda	cnty + 1
	beq	ret
next:	; Draw line
	jsr	render_dots
	dec	cnty
	beq	check
	; Update start address
	clc
	lda	r_s + 0
	adc	#<line
	sta	r_s + 0

	lda	r_s + 1
	adc	#>line
	sta	r_s + 1

	lda	r_s + 2
	adc	#0
	sta	r_s + 2
	jmp	next
check:	; Check if >cnty == 0
	lda	cnty + 1
	beq	ret
	dec	cnty + 1
	jmp	next
	; Finished, return
ret:	pla
	rts
.endproc

	.export render_char
.proc	render_char
	; Prepare LUT address
	clc
	sbc	#' '
	clc
	adc	#<ascii
	sta	cnty
	lda	#>ascii
	adc	#0
	sta	cnty + 1
	; Save registers
	txa
	pha
ret:	; Restore registers
	pla
	tax
	rts
.endproc
