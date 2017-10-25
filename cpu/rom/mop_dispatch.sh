#!/bin/bash
cat - <<-DOC
WIDTH=32;
DEPTH=256;

ADDRESS_RADIX=HEX;
DATA_RADIX=DEC;

CONTENT BEGIN
DOC

cat - | sed 's/#.*//;s/,$//;s/\s//g;s/[,:]/ /g' | grep -v '^$' | sort | \
	awk '{print "\t" $1 ":\t" $4 * 1024 * 1024 + $3 * 1024 + $2 ";\t--\t" $2 ",\t" $3 ",\t" $4}'

cat - <<-DOC
END;
DOC
