onerror { quit -f -code 1 }
#vcd add -r *
#fsdb add -r *
add wave -r -allowconstants /*
run -all
