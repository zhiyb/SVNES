; asmsyntax=asmM6502

	.include "apu.inc"
	.include "ppu.inc"

	.bss
	.reloc
irqcnt:	.byte	0

	.segment "VECT"	; Interrupt vectors
	.word	nmi	; NMI
	.word	main	; Reset
	.word	irq	; IRQ

	.code
	.reloc

.proc	main
	lda	#$ff
	tax
	txs

	lda	#$03	; Enable pulse channels
	sta	apu_status

	; APU pulse channel 1 testing

	lda	#$ce
	sta	apu_pulse1_tmrl

	lda	#$08
	sta	apu_pulse1_lc

	lda	#$ff	; Duty 3, halt, constant
	sta	apu_pulse1_ctrl

	lda	#$9f	; Sweep, period 1, sub, shift 7
	sta	apu_pulse1_sweep

	; APU pulse channel 2 testing

	lda	#$9f	; Duty 2, no halt, constant
	sta	apu_pulse2_ctrl

	lda	#$88
	sta	apu_pulse2_tmrl

reload:	ldx	#60	; Delay 1s
	jsr	delay
	lda	#$10
	sta	apu_pulse2_lc
	jmp	reload
.endproc

.proc	delay	; Delay, time unit: 1/60 s, length: X
	pha		; Push A
	stx	irqcnt
	cli		; Waiting for 60Hz APU IRQ
@loop:	lda	irqcnt
	bne	@loop
	sei
	pla		; Pull A
	rts		; Return
.endproc

.proc	irq
	pha		; Push A
	dec	irqcnt
	bit	apu_status	; Clean frame interrupt
	pla		; Pull A
	rti
.endproc

.proc	nmi
	jmp	nmi
.endproc

	.segment "DMC"
