#!/bin/bash -e

pkg_files=(
)

rtl_files=(
common/fifo_async.sv
common/fifo_sync.sv
)

sim_files=(
sim/tb_fifo_async.sv
sim/tb_fifo_sync.sv
)

prj_dir=$PWD
modelsim_dir=modelsim

top=

vlib=vlib
vmap=vmap
vlog=vlog
vsim=vsim
if ! which $vsim > /dev/null; then
	# Running on WSL
	vlib=$vlib.exe
	vmap=$vmap.exe
	vlog=$vlog.exe
	vsim=$vsim.exe
	prj_dir="$(wslpath -w "$prj_dir")"
fi

sim_comp()
{
	mkdir -p "$modelsim_dir"
	(
		cd "$modelsim_dir"
		$vlib msim_lib
		$vmap work msim_lib
		for file in "${pkg_files[@]}" "${rtl_files[@]}" "${sim_files[@]}"; do
			$vlog -sv "$prj_dir/$file"
		done
	)
}

sim_run()
{
	gui="-c"
	sim_top="TB"

	while (($# > 0)); do
		if [ "$1" == "-gui" ]; then
			gui="-gui"
			shift
		else
			sim_top="$1"
			shift
		fi
	done

	(
		cd "$modelsim_dir"
		$vsim "$gui" \
			-do "vsim -wlf \"$sim_top.wlf\" -l altera_mf work.$sim_top" \
			-do 'add log -r sim:/*' \
			-do 'run -all'
	)
}

sim()
{
	sim_comp
	sim_run "$@"
}

wave()
{
	sim_top="$1"
	(
		cd "$modelsim_dir"
		$vsim -gui "$sim_top.wlf"
	)
}

if (($# < 1)); then
	echo "help? nah"
	echo "$0 sim -gui TB_FIFO_SYNC"
	echo "$0 sim TB_FIFO_SYNC"
	echo "$0 wave TB_FIFO_SYNC"
fi

eval "$@"
