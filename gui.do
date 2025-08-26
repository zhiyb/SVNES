# onerror { quit -f -code 1 }
# run 825ms
add wave -r -allowconstants /TB_NES_TOP/nes/mapper/rpt
add wave -r -allowconstants /TB_NES_TOP/nes/cpu/cpu/*
# add wave -r -allowconstants /TB_NES_TOP/nes/ppu/*
# add wave -r -allowconstants /TB_WRAPPER/w0/nes_dma/*
# run 100ms
# vcd add -r *
# fsdb add -r *
# add wave -r -allowconstants /*
run -all
