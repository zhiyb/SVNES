; asmsyntax=asmM6502

	.bss
	.org	$4000

apu_pulse1_ctrl:	.byte	0
apu_pulse1_sweep:	.byte	0
apu_pulse1_tmrl:	.byte	0
apu_pulse1_lc:		.byte	0

apu_pulse2_ctrl:	.byte	0
apu_pulse2_sweep:	.byte	0
apu_pulse2_tmrl:	.byte	0
apu_pulse2_lc:		.byte	0

apu_tri_ctrl:		.byte	0
apu_tri_RES0:		.byte	0
apu_tri_tmrl:		.byte	0
apu_tri_lc:		.byte	0

apu_noise_ctrl:		.byte	0
apu_noise_RES0:		.byte	0
apu_noise_period:	.byte	0
apu_noise_lc:		.byte	0

apu_dmc_ctrl:		.byte	0
apu_dmc_load:		.byte	0
apu_dmc_saddr:		.byte	0
apu_dmc_len:		.byte	0

apu_RES0:		.byte	0
apu_status:		.byte	0
apu_RES1:		.byte	0
apu_fc:			.byte	0

	.reloc
