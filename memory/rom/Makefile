SRC	= rom.s
TRG	= rom
LDFILE	= linker.ld

OBJ	= $(SRC:.s=.o)

all:	$(TRG).hex

%.o: %.s
	ca65 -o $@ $^

$(TRG).bin: $(OBJ)
	ld65 -C $(LDFILE) -o $@ $(OBJ)

%.hex: %.bin
	srec_cat $< -binary -o $@ -intel

clean:
	rm -f $(OBJ) $(TRG).bin $(TRG).hex
