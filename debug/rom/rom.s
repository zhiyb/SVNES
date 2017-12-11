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

.macro	nextLineCalc
	; Calculate offset for next line
	clc
	lda	#<(lsize * text_h)
	adc	r_s + 0
	pha
	lda	#>(lsize * text_h)
	adc	r_s + 1
	pha
	lda	#0
	adc	r_s + 2
	pha
.endmacro

.macro	nextLine
	; Next line
	pla
	sta	r_s + 2
	pla
	sta	r_s + 1
	pla
	sta	r_s + 0
	nextLineCalc
.endmacro

.macro	string	str, clr
	_CPA	r_c, clr, 2
	_CPA	r_w, str, 2
	jsr	render_string
.endmacro

.macro	scan	data, clr
	_CPA	r_c, clr, 2
	lda	data
	dbg_scan
	jsr	render_hex
.endmacro

.proc	main
	; Render background rectangle
	_CPA	r_s, #offset - margin * lsize - margin, 3
	_CPA	r_w, #width + margin * 2, 2
	_CPA	r_h, #height + margin * 2, 2
	_CPA	r_c, #bg, 2
	jsr	render_rect

loop:	dbg_load
	_CPA	r_s, #offset, 3

	nextLineCalc
	string	#str_01, #text	; Runtime
	scan	#$00, #green
	string	#str_02, #text	; Memtest
	scan	#$00, #red

	nextLine
	string	#str_03, #text	; Address
	scan	#$00, #addr
	scan	#$00, #addr
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
	scan	#$00, #addr

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
