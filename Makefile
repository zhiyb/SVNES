SOURCES			:= $(shell ./scripts/sources.sh)
FILELISTS		:= $(shell ./scripts/filelists.sh)
SIM_LIB			:= sim_lib
DO				?= batch.do
SIM_SYN_ARGS	?= +define+SIMULATION=1
SIM_RUN_ARGS	?= -batch $(DO:%=-do %)

PRJ		?= SVNES
REV		?= DE0_Nano
TEST	?= tb_wrapper tb_sdram tb_fifo_sync tb_fifo_async tb_tft
WAVE	?= $(TEST:%=sim/%.wlf)

#MSIM		?= /mnt/c/Programs/Quartus/18.1/modelsim_ase/win32aloem
#EXE_SFX	?= .exe

MSIM		?= /opt/quartus/20.1/modelsim_ase/linuxaloem
QUARTUS		?= /opt/quartus/20.1/quartus/bin
EXE_SFX		?=

VLIB	:= $(MSIM)/vlib$(EXE_SFX)
VMAP	:= $(MSIM)/vmap$(EXE_SFX)
VSIM	:= $(MSIM)/vsim$(EXE_SFX)
VLOG	:= $(MSIM)/vlog$(EXE_SFX)
VCOM	:= $(MSIM)/vcom$(EXE_SFX)

QMAP	:= $(QUARTUS)/quartus_map$(EXE_SFX)
QFIT	:= $(QUARTUS)/quartus_fit$(EXE_SFX)
QASM	:= $(QUARTUS)/quartus_asm$(EXE_SFX)
QSTA	:= $(QUARTUS)/quartus_sta$(EXE_SFX)

ifeq ($(SOURCES),)
$(error No source files)
endif

include gmsl

.DELETE_ON_ERROR:
.SECONDARY:

.PHONY: all
all: test sof sta

# ModelSim simulation

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

# Quartus FPGA synthesis
CLEAN_DIRS	+= db incremental_db output_files

output_files/$(REV).map.rpt: filelist.qsf $(SOURCES)
	$(QMAP) --read_settings_files=on --write_settings_files=off $(PRJ) -c $(REV)

output_files/$(REV).fit.rpt: output_files/$(REV).map.rpt
	$(QFIT) --read_settings_files=off --write_settings_files=off $(PRJ) -c $(REV)

.PHONY: sof
sof: output_files/$(REV).sof

output_files/$(REV).asm.rpt output_files/$(REV).sof: output_files/$(REV).fit.rpt
	$(QASM) --read_settings_files=off --write_settings_files=off $(PRJ) -c $(REV)

.PHONY: sta
sta: output_files/$(REV).sta.rpt
	! grep -F 'Critical Warning (332148)' output_files/DE0_Nano.sta.rpt

output_files/$(REV).sta.rpt: output_files/$(REV).fit.rpt
	$(QSTA) $(PRJ) -c $(REV)

.PHONY: clean
clean:
	rm -rf $(CLEAN_DIRS)
	rm -f $(CLEAN_FILES)
