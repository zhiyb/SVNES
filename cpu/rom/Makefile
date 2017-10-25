all: mop.mif mop_dispatch.mif

%.mif: %.txt %.sh
	./$*.sh < $< > $@
