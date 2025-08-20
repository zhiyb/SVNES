; asmsyntax=asmM6502

	.bss
nmicnt:	.byte	0
irqcnt:	.byte	0
cnt:	.byte	0

	.segment "VECT"	; Interrupt vectors
	.word	nmi		; NMI
	.word	main	; Reset
	.word	irq		; IRQ

	.code

.proc	main
	lda	#$ff
	tax
	txs

loop:
	inc cnt
	jmp	loop
.endproc

.proc	irq
	dec	irqcnt
	; bit	apu_status	; Clean frame interrupt
	rti
.endproc

.proc	nmi
	dec	nmicnt
	rti
.endproc

	.rodata
