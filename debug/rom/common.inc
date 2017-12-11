; asmsyntax=asmM6502

	margin	= 8
	top	= 120
	left	= 406
	width	= 274
	height	= 240
	lsize	= 800
	offset	= $fa0000 + top * lsize + left

	text_w	= 6
	text_h	= 8

	white	= $ffff
	black	= $0000
	red	= $f800
	green	= $07c0
	blue	= $001f
	yellow	= red | green
	cyan	= green | blue
	magenta	= red | blue

	bg	= black
	text	= yellow
	text_bg	= $0841
	addr	= magenta
	data	= cyan
	read	= green
	write	= red
	test	= $667f

; dst = dst + src + C
.macro	_ADCA	dst, src, size
	.if (.match(.left(1, {src}), #))
		; Immediate mode
		lda	#<(.right(.tcount({src}) - 1, {src}))
		adc	dst
		sta	dst
		.if (size >= 2)
			lda	#>(.right(.tcount({src}) - 1, {src}))
			adc	dst + 1
			sta	dst + 1
		.endif
		.if (size >= 3)
			lda	#((.right(.tcount({src}) - 1, {src})) >> 16)
			adc	dst + 2
			sta	dst + 2
		.endif
	.else
		lda	src
		adc	dst
		sta	dst
		.if (size >= 2)
			lda	src + 1
			adc	dst + 1
			sta	dst + 1
		.endif
		.if (size >= 3)
			lda	src + 2
			adc	dst + 2
			sta	dst + 2
		.endif
	.endif
.endmacro

; Copy 1 to 4 bytes from `src' to `dst'
.macro	_CPA	dst, src, size
	.if (.match(.left(1, {src}), #))
		; Immediate mode
		.if (size >= 4)
			lda	#((.right(.tcount({src}) - 1, {src})) >> 24)
			sta	dst + 3
		.endif
		.if (size >= 3)
			lda	#((.right(.tcount({src}) - 1, {src})) >> 16)
			sta	dst + 2
		.endif
		.if (size >= 2)
			lda	#>(.right(.tcount({src}) - 1, {src}))
			sta	dst + 1
		.endif
		lda	#<(.right(.tcount({src}) - 1, {src}))
		sta	dst
	.else
		.if (size >= 4)
			lda	src + 3
			sta	dst + 3
		.endif
		.if (size >= 3)
			lda	src + 2
			sta	dst + 2
		.endif
		.if (size >= 2)
			lda	src + 1
			sta	dst + 1
		.endif
		lda	src
		sta	dst
	.endif
.endmacro
