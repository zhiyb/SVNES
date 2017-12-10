SRC	= rom.s render.s ascii.s
TRG	= rom
LDFILE	= linker.ld
CPU	= 6502

OBJ	= $(SRC:.s=.o)

all:	$(TRG).hex

rom.o: common.inc render.inc
render.o: common.inc debug.inc

%.o: %.s
	ca65 --cpu $(CPU) -o $@ $<

$(TRG).map $(TRG).bin: $(OBJ) $(LDFILE)
	ld65 -C $(LDFILE) -o $@ $(OBJ) -m $(TRG).map

%.hex: %.bin
	srec_cat $< -binary -o $@ -intel

%.bin.dump: %.bin
	hd $< > $@

clean:
	rm -f $(OBJ) $(TRG).bin $(TRG).hex $(TRG).bin.dump
