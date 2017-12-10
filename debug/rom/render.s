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
	_CPA	cntx, r_w, 2
	; Check if cntx == 0
	bne	start
	lda	cntx + 1
	beq	ret
start:	; Set start address
	_CPA	dbg_addr, r_s, 3
	_CPA	dbg_data + 1, r_c + 1, 1
next:	; Fill a pixel
	_CPA	dbg_data, r_c, 1
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
	_CPA	cnty, r_h, 2
	; Check if cnty == 0
	bne	next
	lda	cnty + 1
	beq	ret
next:	; Draw line
	jsr	render_dots
	dec	cnty
	beq	check
	; Add 1 line to start address
	clc
	_ADCA	r_s, #lsize, 3
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
	pha
	; Prepare LUT address
	clc
	sbc	#' '
	pha
	lda	#0
	sta	cnty + 1
	pla
	; 8 bytes per character
	asl
	rol	cnty + 1
	asl
	rol	cnty + 1
	asl
	rol	cnty + 1
	adc	#<ascii
	sta	cnty
	lda	#>ascii
	adc	cnty + 1
	sta	cnty + 1
	; Save registers
	tya
	pha
	; Loop through lines
	ldy	#0
line:	; Set start address
	_CPA	dbg_addr, r_s, 3
	; Loop through pixels
	lda	#text_w
	sta	cntx
	lda	(cnty), Y
	sta	cntx + 1
dot:	; Render pixels
	asl	cntx + 1
	bcc	bg
	; Foreground colour
	_CPA	dbg_data, r_c, 2
	jmp	next
bg:	; Background colour
	_CPA	dbg_data, #text_bg, 2
next:	; Next dot
	dec	cntx
	bne	dot
	; Next line
	iny
	cpy	#text_h
	beq	ret
	; Add 1 line to start address
	clc
	_ADCA	r_s, #lsize, 3
	jmp	line
ret:	; Restore registers
	pla
	tay
	pla
	rts
.endproc

	.export render_string
.proc	render_string
	; Save registers
	pha
	tya
	pha
	; Initialisation
	ldy	#0
next:	; Read a character
	lda	(r_w), Y
	beq	ret
	sta	cntx
	; Calculate next character offset
	clc
	lda	r_s + 0
	adc	#text_w
	pha
	lda	r_s + 1
	adc	#0
	pha
	lda	r_s + 2
	adc	#0
	pha
	; Draw character
	lda	cntx
	jsr	render_char
	; Next character
	iny
	pla
	sta	r_s + 2
	pla
	sta	r_s + 1
	pla
	sta	r_s + 0
	jmp	next
ret:	; Restore registers
	pla
	tay
	pla
	rts
.endproc
