#!/bin/bash -e

readlist()
{
	pdir="$1"
	if [ ! -e "$pdir/filelist" ]; then
		echo "$0: No filelist found in $pdir" >&2
		return 1
	fi

	dir=()
	file=()
	for e in $(<"$pdir/filelist"); do
		e="$pdir/$e"
		if [ -d "$e" ]; then
			dir[${#dir[@]}]="$e"
		elif [ -e "$e" ]; then
			file[${#file[@]}]="$e"
		else
			echo "$0: File $pdir/$e not valid" >&2
			return 1
		fi
	done

	echo ${file[@]}
	for d in ${dir[@]}; do
		readlist "$d";
	done
}

files="$(readlist src)" && echo $files
