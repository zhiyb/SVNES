onerror { quit -f -code 1 }
add wave -r -allowconstants /TB_NES_TOP/nes/mapper/rpt
# run 85ms
add wave -r -allowconstants /TB_NES_TOP/nes/cpu/*
# add wave -r -allowconstants /TB_NES_TOP/nes/ppu/*
# add wave -r -allowconstants /TB_NES_TOP/nes_dma/*
#run 100ms
#vcd add -r *
#fsdb add -r *
#add wave -r -allowconstants /*
run -all
