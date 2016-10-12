; asmsyntax=asmM6502

	.bss
	.org	$2000

ppu_ctrl:	.byte	0
ppu_mask:	.byte	0
ppu_status:	.byte	0
oam_addr:	.byte	0
oam_data:	.byte	0
ppu_scroll:	.byte	0
ppu_addr:	.byte	0
ppu_data:	.byte	0

	.org	$4014

oam_mda:	.byte	0

	.reloc
