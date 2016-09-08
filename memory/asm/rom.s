; asmsyntax=asmM6502

	.segment "VECT"	; Interrupt vectors
	.word	reset	; NMI
	.word	reset	; Reset
	.word	irq	; IRQ

	.bss
irqcnt:	.res	1

	.code
reset:	lda	#$ff
	tax
	txs
	sta	$3004	; gpio1_dir
	lda	#$00
	tay
	sta	$3005	; gpio1_out

	lda	#$1f	; enable all channels
	sta	$4015	; apu_status

	lda	#$ce
	sta	$4002	; apu_pulse1_tmrl

	lda	#$08
	sta	$4003	; apu_pulse1_lc

	lda	#$ff	; duty 3, halt, constant
	sta	$4000	; apu_pulse1_ctrl

	lda	#$9f	; sweep, period 1, sub, shift 7
	sta	$4001	; apu_pulse1_sweep

	ldx	#$f0	; delay 4s
	jsr	delay

	lda	#$7f	; no halt
	sta	$4008	; apu_triangle_linear

	lda	#$ce
	sta	$400a	; apu_triangle_tmrl

	lda	#$08
	sta	$400b	; apu_triangle_lc

	ldx	#$3c	; delay 1s
	jsr	delay

	lda	#$2f	; loop, envelope, period 15
	sta	$400c	; apu_noise_ctrl

	lda	#$00
	sta	$400f	; apu_noise_lc

	lda	#$00
noise0:	sta	$400e	; apu_noise_cfg
	sta	$400f	; apu_noise_lc
	ldx	#$1e	; delay 500ms
	jsr	delay
	clc
	adc	#$01
	cmp	#$10
	bne	noise0

	lda	#$80
noise1:	sta	$400e	; apu_noise_cfg
	sta	$400f	; apu_noise_lc
	ldx	#$1e	; delay 500ms
	jsr	delay
	clc
	adc	#$01
	cmp	#$90
	bne	noise1

	lda	#$1f	; no halt, constant, volume 15
	sta	$400c	; apu_noise_ctrl

	lda	#$08
	sta	$400f	; apu_noise_lc

	lda	#$9f	; duty 2, no halt, constant
	sta	$4004	; apu_pulse2_ctrl

	lda	#$88
	sta	$4006	; apu_pulse2_tmrl

reload:	ldx	#$3c	; Delay 1s
	jsr	delay
	lda	#$10
	sta	$4007	; APU_PULSE2_LC
	iny
	sty	$3005	; GPIO1_OUT
	clv
	bvc	reload

delay:	pha		; Push A
	txa
	pha		; Push X
	cli		; Waiting for 60Hz APU IRQ
loop:	txa
	bne	loop
	sei
	pla		; Pull X
	tax
	pla		; Pull A
	rts		; Return

irq:	pha		; Push A
	dex
	dec	irqcnt	; Decrement irqcnt
	lda	$4015	; Clean frame interrupt
	pla		; Pull A
	rti
