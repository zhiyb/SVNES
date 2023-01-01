#!/bin/bash -e

readlist()
{
	local pdir="$1"
	if [ ! -e "$pdir/filelist" ]; then
		echo "$0: No filelist found in $pdir" >&2
		return 1
	fi

	for f in $(<"$pdir/filelist"); do
		local e="$(realpath -m --relative-to=. "$pdir/$f")"
		if [ -d "$e" ]; then
			readlist "$e"
		elif [ -e "$e" ]; then
			echo "$e"
		else
			echo "$0: File $e not valid" >&2
			return 1
		fi
	done
}

files="$(readlist src)" && echo $files
