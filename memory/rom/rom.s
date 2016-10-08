; asmsyntax=asmM6502

	.include "apu.inc"
	.include "ppu.inc"

	.bss
	.reloc
irqcnt:	.byte	0
test:	.byte	0

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

	lda	#$09	; Enable noise and pulse channels
	sta	apu_status

	;	PASS and FAIL notification sounds
	ldx	#$00
	stx	test
	cpx	test
	jsr	notify

	ldx	#$80
	cpx	test
	jsr	notify

	lda	#30
	jsr	delay

	;	PPU RAM test
	bit	ppu_status	; Reset address latch

	;	Sequential write from $0000
	lda	#$00
	sta	ppu_addr
	sta	ppu_addr

	ldx	#$00
@testw:	stx	ppu_data
	inx
	bne	@testw
	clc
	adc	#$01
	cmp	#$28
	bne	@testw

test0:	;	Sequential read from $0000
	lda	#$00
	sta	ppu_addr
	sta	ppu_addr

	ldx	#$00
@testr:	cpx	ppu_data
	bne	@fail
	inx
	bne	@testr
	adc	#$01
	cmp	#$28
	bne	@testr
	lda	#$00
	jsr	notify
	jmp	test1

@fail:	lda	#80
	jsr	notify

test1:	;	Sequential read from $007f
	lda	#$00
	sta	ppu_addr
	lda	#$7f
	sta	ppu_addr

	tax
	lda	#$00
	;ldx	#$00
@testr:	cpx	ppu_data
	bne	@fail
	inx
	bne	@testr
	adc	#$01
	cmp	#$28
	bne	@testr
	lda	#$00
	jsr	notify
	jmp	done

@fail:	lda	#80
	jsr	notify

done:	lda	#$9f	; Duty 2, no halt, constant
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
