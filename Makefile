SOURCES		:= $(shell ./sourcelist.sh)
SIM_LIB		:= sim_lib
DO		?= batch.do
SIM_ARGS	?= -batch

TEST		?= tb
WAVE		?= $(TEST:%=sim/%.wlf)

MODELSIM	:= /mnt/c/Programs/Quartus/18.1/modelsim_ase/win32aloem
MODELSIM_SFX	:= .exe

VLIB	:= $(MODELSIM)/vlib$(MODELSIM_SFX)
VMAP	:= $(MODELSIM)/vmap$(MODELSIM_SFX)
VSIM	:= $(MODELSIM)/vsim$(MODELSIM_SFX)
VLOG	:= $(MODELSIM)/vlog$(MODELSIM_SFX)
VCOM	:= $(MODELSIM)/vcom$(MODELSIM_SFX)

ifeq ($(SOURCES),)
$(error No source files)
endif

include gmsl

.DELETE_ON_ERROR:
.SECONDARY:

all: test

test: $(WAVE)

CLEAN_DIRS	+= sim
sim: %:
	mkdir -p $@

sim/%.wlf: src/testbench/%.do $(SIM_LIB)/_lib.qdb | sim
	$(VSIM) -work $(SIM_LIB) -wlf $@ -logfile sim/$*.log $(DO:%=-do %) -do $< $(call uc,$(notdir $*)) $(SIM_ARGS)

view: $(WAVE)
	$(VSIM) -gui -logfile sim/view.log -view $^

$(SIM_LIB)/_lib.qdb: $(SOURCES) | modelsim.ini
	$(VLOG) -work $(SIM_LIB) -sv $(filter %.sv,$(SOURCES))

CLEAN_FILES	+= modelsim.ini
modelsim.ini: $(SIM_LIB)/_info
	$(VMAP) work $<
	$(VMAP)

CLEAN_DIRS	+= $(SIM_LIB)
%/_info:
	$(VLIB) $*

.PHONY: clean
clean:
	rm -rf $(CLEAN_DIRS)
	rm -f $(CLEAN_FILES)
