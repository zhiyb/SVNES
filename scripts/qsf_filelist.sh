#!/bin/bash -e

for f in "$@"; do
	if [[ "$f" == *"/testbench/"* ]]; then
		continue
	fi
	ext="${f##*.}"
	if [ "$ext" == sv ]; then
		echo "set_global_assignment -name SYSTEMVERILOG_FILE \"$f\""
	elif [ "$ext" == v ]; then
		echo "set_global_assignment -name VERILOG_FILE \"$f\""
	elif [ "$ext" == qip ]; then
		echo "set_global_assignment -name QIP_FILE \"$f\""
	elif [ "$ext" == sdc ]; then
		echo "set_global_assignment -name SDC_FILE \"$f\""
	elif [ "$ext" == qsf ]; then
		echo "source \"$f\""
	fi
done
