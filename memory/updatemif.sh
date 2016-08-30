#!/bin/bash
IFS=""
ls -1 *.mif | while read mif; do
	txt="${mif%.*}.txt"
	[ -e "$txt" ] || continue
	echo "Processing: $txt -> $mif"
	sed '/CONTENT BEGIN/,$ d' "$mif" > "$mif.tmp"
	echo "CONTENT BEGIN" >> "$mif.tmp"
	while read line; do
		[ -z "$line" ] && continue;
		[ "${line:0:1}" != "	" ] && \
			printf "\t%03x  :   " "$((i++))" >> "$mif.tmp"
		echo "$line" >> "$mif.tmp"
	done < "$txt"
	echo "END;" >> "$mif.tmp"
	sed '1,/END;/ d' "$mif" >> "$mif.tmp"
	mv "$mif" "$mif.bak"
	mv "$mif.tmp" "$mif"
done
