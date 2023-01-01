SOURCES			:= $(shell ./scripts/sources.sh)
FILELISTS		:= $(shell ./scripts/filelists.sh)
SIM_LIB			:= sim_lib
DO				?= batch.do
SIM_SYN_ARGS	?= +define+SIMULATION=1
SIM_RUN_ARGS	?= -batch $(DO:%=-do %)

TEST		?= tb_wrapper tb_sdram tb_fifo_sync tb_fifo_async tb_tft
WAVE		?= $(TEST:%=sim/%.wlf)

#MSIM		?= /mnt/c/Programs/Quartus/18.1/modelsim_ase/win32aloem
#MSIM_SFX	?= .exe

MSIM		?= /opt/quartus/20.1/modelsim_ase/linuxaloem
MSIM_SFX	?=

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
all: test filelist.qsf

.PHONY: test
test: $(WAVE)

.PHONY: view
view: $(WAVE)
	$(VSIM) -work $(SIM_LIB) -gui -logfile sim/view.log -view $^

CLEAN_DIRS	+= sim
sim: %:
	mkdir -p $@

sim/%.wlf: src/testbench/%.sv $(SIM_LIB)/_lib.qdb | sim
	$(VSIM) -work $(SIM_LIB) -wlf $@ -logfile sim/$*.log $(call uc,$(notdir $*)) $(SIM_RUN_ARGS)

$(SIM_LIB)/_lib.qdb: $(SOURCES) $(FILELISTS) | modelsim.ini
	$(VLOG) -work $(SIM_LIB) -v $(filter %.v,$(SOURCES)) -sv $(filter %.sv,$(SOURCES)) $(SIM_SYN_ARGS)

CLEAN_FILES	+= filelist.qsf
filelist.qsf: scripts/qsf_filelist.sh $(FILELISTS)
	./scripts/qsf_filelist.sh $(SOURCES) > $@

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
