SOURCES		:= $(shell ./sourcelist.sh)
SIM_LIB		:= sim_lib
DO		?= batch.do
SIM_ARGS	?= -batch

TEST		?= tb tb_sdram
WAVE		?= $(TEST:%=sim/%.wlf)

MSIM		?= /mnt/c/Programs/Quartus/18.1/modelsim_ase/win32aloem
MSIM_SFX	?= .exe

VLIB	:= $(MSIM)/vlib$(MSIM_SFX)
VMAP	:= $(MSIM)/vmap$(MSIM_SFX)
VSIM	:= $(MSIM)/vsim$(MSIM_SFX)
VLOG	:= $(MSIM)/vlog$(MSIM_SFX)
VCOM	:= $(MSIM)/vcom$(MSIM_SFX)

ifeq ($(SOURCES),)
$(error No source files)
endif

include gmsl

.DELETE_ON_ERROR:
.SECONDARY:

.PHONY: all
all: test

.PHONY: test
test: $(WAVE)

.PHONY: view
view: $(WAVE)
	$(VSIM) -work $(SIM_LIB) -gui -logfile sim/view.log -view $^

CLEAN_DIRS	+= sim
sim: %:
	mkdir -p $@

sim/%.wlf: src/testbench/%.do $(SIM_LIB)/_lib.qdb | sim
	$(VSIM) -work $(SIM_LIB) -wlf $@ -logfile sim/$*.log $(DO:%=-do %) -do $< $(call uc,$(notdir $*)) $(SIM_ARGS)

$(SIM_LIB)/_lib.qdb: $(SOURCES) | modelsim.ini
	$(VLOG) -work $(SIM_LIB) -sv $(filter %.sv,$(SOURCES))

CLEAN_FILES	+= modelsim.ini
modelsim.ini: $(SIM_LIB)/_info
	$(VMAP) work $(SIM_LIB)

CLEAN_DIRS	+= $(SIM_LIB)
%/_info:
	$(VLIB) $*

.PHONY: clean
clean:
	rm -rf $(CLEAN_DIRS)
	rm -f $(CLEAN_FILES)
