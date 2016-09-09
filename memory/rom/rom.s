; asmsyntax=asmM6502

	.include	"apu.inc"

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
	sta	$3004	; GPIO1_DIR
	lda	#$00
	tay
	sta	$3005	; GPIO1_OUT

	; APU DMC testing

	lda	#$80
	sta	apu_dmc_load

	lda	#$00
	sta	apu_dmc_len

	lda	#.lobyte(dmc >> 6)
	sta	apu_dmc_addr

	lda	#$40
	sta	apu_dmc_ctrl

	lda	#$1f	; Enable all channels
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

	ldx	#240	; Delay 4s
	jsr	delay

	; APU triangle channel testing

	lda	#$7f	; No halt
	sta	apu_tri_ctrl

	lda	#$ce
	sta	apu_tri_tmrl

	lda	#$08
	sta	apu_tri_lc

	ldx	#60	; Delay 1s
	jsr	delay

	; APU noise channel testing

	lda	#$00
	sta	apu_noise_period

	lda	#$1f	; No halt, constant, volume 15
	sta	apu_noise_ctrl

	lda	#$08
	sta	apu_noise_lc

	; APU pulse channel 2 testing

	lda	#$9f	; Duty 2, no halt, constant
	sta	apu_pulse2_ctrl

	lda	#$88
	sta	apu_pulse2_tmrl

reload:	ldx	#60	; Delay 1s
	jsr	delay
	lda	#$10
	sta	apu_pulse2_lc
	iny
	sty	$3005	; GPIO1_OUT
	jmp	reload
.endproc

	; Delay, time unit: 1/60 s, length: X
.proc	delay
	pha		; Push A
	stx	irqcnt
	cli		; Waiting for 60Hz APU IRQ
loop:	lda	irqcnt
	bne	loop
	sei
	pla		; Pull A
	rts		; Return
.endproc

.proc	nmi
	rti
.endproc

.proc	irq
	pha		; Push A
	dec	irqcnt
	lda	apu_status	; Clean frame interrupt
	pla		; Pull A
	rti
.endproc

	; DMC sample data
	.segment	"DMC"
dmc:	.byte	$f0
