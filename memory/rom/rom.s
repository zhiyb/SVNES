; asmsyntax=asmM6502

	.include "apu.inc"
	.include "ppu.inc"
	.include "data.inc"

	.bss
irqcnt:	.byte	0
test:	.byte	0

	.segment "VECT"	; Interrupt vectors
	.word	nmi	; NMI
	.word	main	; Reset
	.word	irq	; IRQ

	.code

.proc	main
	lda	#$ff
	tax
	txs

	lda	#$09	; Enable noise and pulse channels
	sta	apu_status

	; Wait for PPU startup
	bit	ppu_status
@ppuw0:	bit	ppu_status
	bpl	@ppuw0
@ppuw1:	bit	ppu_status
	bpl	@ppuw1

	; PPU memory initialisation
	jsr	ppu_data_init

	; PASS and FAIL notification sounds
sounds:	ldx	#$00
	stx	test
	cpx	test
	;jsr	notify

	ldx	#$80
	cpx	test
	;jsr	notify

	lda	#30
	;jsr	delay

	; Waiting for PPU vblank
	bit	ppu_status
@ppuw0:	bit	ppu_status
	bpl	@ppuw0
	; Enable PPU rendering
	lda	#$00
	sta	ppu_ctrl
	lda	#$1e
	sta	ppu_mask
	lda	#$00
	sta	ppu_scroll
	sta	ppu_scroll

	lda	#$9f	; Duty 2, no halt, constant
	sta	apu_pulse1_ctrl
	lda	#$00	; Disable sweep
	sta	apu_pulse1_sweep
	lda	#$68
	sta	apu_pulse1_tmrl
	lda	#$30
	sta	apu_pulse1_lc
	jmp	*
.endproc

.proc	notify
	pha
	bne	@fail
	lda	#$9f	; Duty 2, no halt, constant
	sta	apu_pulse1_ctrl
	lda	#$00	; Disable sweep
	sta	apu_pulse1_sweep
	lda	#$70
	sta	apu_pulse1_tmrl
	lda	#$10
	sta	apu_pulse1_lc
	jmp	@delay
@fail:
	lda	#$1f	; No halt, constant
	sta	apu_noise_ctrl
	lda	#$06
	sta	apu_noise_period
	lda	#$10
	sta	apu_noise_lc
@delay:
	lda	#30
	jsr	delay
	pla
	rts
.endproc

.proc	delay	; Delay, time unit: 1/60 s, length: A
	pha		; Push A
	sta	irqcnt
	cli		; Waiting for 60Hz APU IRQ
@loop:	lda	irqcnt
	bne	@loop
	sei
	pla		; Pull A
	rts		; Return
.endproc

.proc	irq
	dec	irqcnt
	bit	apu_status	; Clean frame interrupt
	rti
.endproc

.proc	nmi
	jmp	nmi
.endproc

	.segment "DMC"

	.rodata
