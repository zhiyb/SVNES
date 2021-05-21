#!/bin/bash -e
cat - <<-DOC
WIDTH=8;
DEPTH=1024;

ADDRESS_RADIX=HEX;
DATA_RADIX=DEC;

CONTENT BEGIN
DOC

cat - | sed 's/#.*//;s/\s//g;s/^\([0-9a-f][0-9a-f]:\)/0x\1/;s/[,:]/ /g' | grep -v '^$' | sort | \
	awk --non-decimal-data '{printf "\t%x:\t%d;\n\t%x:\t%d;\n\t%x:\t%d;\n", $1 * 4, $2, $1 * 4 + 1, $3, $1 * 4 + 2, $4}'

cat - <<-DOC
END;
DOC
