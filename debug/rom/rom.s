; asmsyntax=asmM6502

	.include "common.inc"
	.include "render.inc"
	.include "debug.inc"
	.reloc

	.segment "VECT"	; Interrupt vectors
	.word	0	; NMI
	.word	main	; Reset
	.word	0	; IRQ

	.zeropage
t1:	.byte	0
t2:	.byte	0
t3:	.byte	0
t4:	.byte	0
soff:	.dword	0

	.code

.proc	_nextLine
	; Update start offset
	_CPA	r_s, soff, 3
	; Calculate offset for next line
	clc
	_ADCA	soff, #lsize * text_h, 3
	rts
.endproc

.macro	nextLine
	jsr	_nextLine
.endmacro

.macro	setClr	clr
	.ifnblank	clr
		_CPA	r_c, clr, 2
	.endif
.endmacro

.macro	string	str, clr
	setClr	clr
	_CPA	r_w, str, 2
	jsr	render_string
.endmacro

.proc	_dScan
	lda	data
	dbg_scan
	rts
.endproc

.macro	dScan	data
	jsr	_dScan
.endmacro

.macro	scan	data, clr
	setClr	clr
	dScan	data
	jsr	render_hex
.endmacro

.proc	charCheck
	bcs	@show
	lda	#' '
@show:	jsr	render_char
	rts
.endproc

.proc	main
	; Render background rectangles
	_CPA	r_s, #ppu_o - ppu_m * lsize - ppu_m, 3
	_CPA	r_w, #ppu_w + ppu_m * 2, 2
	_CPA	r_h, #ppu_h + ppu_m * 2, 2
	_CPA	r_c, #bg, 2
	jsr	render_rect
	_CPA	r_s, #offset - margin * lsize - margin, 3
	_CPA	r_w, #width + margin * 2, 2
	_CPA	r_h, #height + margin * 2, 2
	_CPA	r_c, #bg, 2
	jsr	render_rect

loop:	_CPA	soff, #offset, 3
	dbg_load

	nextLine
	string	#str_01, #text	; Runtime
	scan	#$00, #green
	string	#str_02, #text	; Memtest
	scan	#$00, #red

	nextLine
	string	#str_03, #text	; Address
	scan	#$00, #addr
	scan	#$00
	string	#str_04, #text	; Data
	scan	#$00, #data

	nextLine
	string	#str_05, #text	; A
	scan	#$00, #data
	string	#str_06, #text	; X
	scan	#$00, #data
	string	#str_07, #text	; Y
	scan	#$00, #data
	string	#str_08, #text	; SP
	scan	#$00, #data
	string	#str_09, #text	; P
	scan	#$00, #data
	string	#str_10, #text	; PC
	scan	#$00, #addr
	scan	#$00

	nextLine
	nextLine
	string	#str_11, #text	; Instruction capture
	scan	#$00, #test

_cnt:	dScan	#$00	; cnt
	lsr			; Run status
	pha
	bcc	@stop
@run:	string	#str_14, #green	; RUN
	jmp	@done
@stop:	string	#str_15, #red	; STOP
@done:	setClr	#intrpt		; Interrupts
	pla
_reset:	lsr			; Reset interrupt
	pha
	lda	#'R'
	jsr	charCheck
	pla
_nmi:	lsr			; NMI interrupt
	pha
	lda	#'N'
	jsr	charCheck
	pla
_irq:	lsr			; IRQ interrupt
	pha
	lda	#'I'
	jsr	charCheck

_cycle:	nextLine
	pla			; Instruction cycle counter
	clc
	sta	t1	; counter
	lda	#7 - 1		; Maximum 7 cycles
	sbc	t1	; counter
	cmp	#7
	bmi	@done
	jmp	loop
@done:	sta	t2	; extra

_rw:	dScan	#$00	; rw
	ldx	t2	; extra - 1
	inx		; rw is 8-bit
@shift:	asl
	dex
	bne	@shift
@done:	sta	t3	; rw

_addr:	ldx	t2	; extra
	beq	@show
@skip:	dScan	#$00	; addr
	dScan	#$00	; addr
	dex
	bne	@skip

@show:	setClr	#addr
	ldx	t1	; counter
@next:	scan	#$00	; addr
	scan	#$00	; addr
	lda	#' '
	jsr	render_char
	txa
	beq	@done
	dex
	jmp	@next
@done:
_addre:	ldx	t2	; extra
	beq	@done
@draw:	string	#str_12
	dex
	bne	@draw
@done:

_data:	ldx	t2	; extra
	beq	@show
@skip:	dScan	#$00	; data
	dex
	bne	@skip

@show:	nextLine
	setClr	#data
	lda	#' '
	jsr	render_char
	ldx	t1	; counter
@next:	asl	t3	; rw
	bcc	@write
	setClr	#read
	jmp	@disp
@write:	setClr	#write
@disp:	scan	#$00	; data
	lda	#' '
	jsr	render_char
	jsr	render_char
	jsr	render_char
	txa
	beq	@done
	dex
	jmp	@next
@done:
_datae:	ldx	t2	; extra
	beq	@done
	setClr	#data
@draw:	string	#str_13
	dex
	bne	@draw
@done:


	jmp	loop
.endproc

	.rodata
str_01:	.byte	"Runtime: ", 0
str_02:	.byte	" s, memtest fail: ", 0
str_03:	.byte	"Address: ", 0
str_04:	.byte	", data: ", 0
str_05:	.byte	"A ", 0
str_06:	.byte	" | X ", 0
str_07:	.byte	" | Y ", 0
str_08:	.byte	" | SP ", 0
str_09:	.byte	" | P ", 0
str_10:	.byte	" | PC ", 0
str_11:	.byte	"Instruction capture ", 0
str_12:	.byte	"---- ", 0
str_13:	.byte	"--   ", 0
str_14:	.byte	" RUN  ", 0
str_15:	.byte	" STOP ", 0
