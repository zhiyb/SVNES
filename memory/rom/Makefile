SRC	= rom.s data.s
TRG	= rom
LDFILE	= linker.ld
CPU	= 6502

OBJ	= $(SRC:.s=.o)

all:	$(TRG).hex

rom.o: apu.inc ppu.inc

%.o: %.s
	ca65 --cpu $(CPU) -o $@ $<

$(TRG).bin: $(OBJ) $(LDFILE)
	ld65 -C $(LDFILE) -o $@ $(OBJ)

%.hex: %.bin
	srec_cat $< -binary -o $@ -intel

%.bin.dump: %.bin
	hd $< > $@

clean:
	rm -f $(OBJ) $(TRG).bin $(TRG).hex $(TRG).bin.dump
