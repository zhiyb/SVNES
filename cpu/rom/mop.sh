#!/bin/bash
subst='	s/#.*//;
	s/ALU_ADD/000/; s/ALU_SUB/001/; s/ALU_SL/010/; s/ALU_SR/011/;
	s/ALU_AND/100/; s/ALU_OR/101/; s/ALU_EOR/110/; s/ALU_DEC/111/;
	s/AI_0/0/; s/AI_SB/1/;
	s/BI_DB/00/; s/BI_nDB/01/; s/BI_ADL/10/; s/BI_HLD/11/;
	s/DB_DL/000/; s/DB_PCL/001/; s/DB_PCH/010/; s/DB_SB/011/;
	s/DB_A/100/; s/DB_P/101/;
	s/SB_ALU/000/; s/SB_SP/001/; s/SB_X/010/; s/SB_Y/011/; s/SB_A/100/;
	s/SB_DB/101/; s/SB_FUL/111/;
	s/AD_PC/000/; s/\<AD_ZP\>/001/; s/AD_ZPA/010/; s/AD_SP/011/;
	s/AD_ABS/100/; s/AD_INT/101/; s/AD_ADL/110/; s/AD_ADH/111/;
	s/PC_PC/0/; s/PC_AD/1/;
	s/P_MASK/00/; s/P_SP/01/; s/P_CLR/10/; s/P_SET/11/;
	s/P_NONE/00/; s/\<P_NZ\>/01/; s/\<P_NZC\>/10/; s/\<P_NVZC\>/11/;
	s/P_POP/00/; s/P_BIT/01/; s/P_BRK/10/;
	s/P_C/00/; s/P_D/01/; s/P_I/10/; s/P_V/11/; s/P_Z/01/; s/P_N/10/; s/P_B/11/;
	s/SEQ_0/00/; s/\<SEQ\>/01/; s/SEQ_2/10/;
	s/SEQ_R0/00/; s/SEQ_R1/01/; s/SEQ_R2/10/;
	s/READ/0/; s/WRITE/1/;
	s/L/0/g; s/H/1/g;
	s/\s//g; s/,//g';

cat - <<-DOC
WIDTH=32;
DEPTH=1024;

ADDRESS_RADIX=DEC;
DATA_RADIX=BIN;

CONTENT BEGIN
DOC

cat - | sed "$subst" | grep -v '^$' | awk '{print "\t" NR - 1 ":\t" $0 ";"}'

cat - <<-DOC
END;
DOC
