#!/bin/bash

# Create variables with paths and names of input files

dbpath='/scratch/cwcharle/busco_downloads/lineages'
dbname='passeriformes_odb10'
#dbext='.2024-01-08.tar.gz'

hifiasm_results_dir='/scratch/cwcharle/fir-hifiasm/'
input_jobtime='2026-Aug-31_22-33-37'
genomepath=${hifiasm_results_dir}/${input_jobtime}
genomename='hifiasm.asm.hic.hap1.p_ctg.fasta'
genomename2='hifiasm.asm.hic.hap2.p_ctg.fasta'

contpath='/home/cwcharle/projects/def-dirwin/cwcharle/annotation-prep/'
contname='busco_v5.8.0_cv1.sif'

printf "Extracting fasta"

/home/cwcharle/project/fir-hifiasm/gfatools/gfatools \
gfa2fa \
${genomepath}/hifiasm.asm.hic.hap1.p_ctg.gfa \
> ${genomepath}/hifiasm.asm.hic.hap1.p_ctg.fasta

/home/cwcharle/project/fir-hifiasm/gfatools/gfatools \
gfa2fa \
${genomepath}/hifiasm.asm.hic.hap2.p_ctg.gfa \
> ${genomepath}/hifiasm.asm.hic.hap2.p_ctg.fasta

printf "Finished extracting fasta"

printf "Attempting to run busco"

apptainer run \
-C \
-B .:/busco_wd \
-W . \
--compat \
--cwd /busco_wd \
${contpath}/${contname} \
busco \
-i ${genomepath}/${genomename} \
-m genome \
-l ${dbpath}/${dbname} \
-c 1 \
-o hap_1 \
--metaeuk

apptainer run \
-C \
-B .:/busco_wd \
-W . \
--compat \
--cwd /busco_wd \
${contpath}/${contname} \
busco \
-i ${genomepath}/${genomename2} \
-m genome \
-l ${dbpath}/${dbname} \
-c 1 \
-o hap_2 \
--metaeuk

printf "busco run finished"

