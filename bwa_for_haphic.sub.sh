#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=28
#SBATCH --mem=128G
#SBATCH --job-name="bwa_for_haphic.sub.sh"
#SBATCH --account=def-dirwin
#SBATCH --output=job_%j.out
#SBATCH --mail-user=cwc@zoology.ubc.ca
#SBATCH --mail-type=ALL

# Setting initial variables

scratchpath="/home/cwcharle/scratch"

this_filename="bwa_for_haphic.sub.sh"

prologue_filename="tools/single_job_prologue.sh"

# Run prologue script to take care of some logging and synchronize jobtimes
source ${prologue_filename}

# Load modules
printf "\nCurrently loaded modules\n"
module list

module load \
bwa/0.7.18 \
samblaster/0.1.26 \
samtools/1.22.1

printf "\nCurrently loaded modules\n"
module list

# Create variables with paths and names of input and output files
# This is the last spot where you need to ADD VARIABLES (3/3)

## Paths to important directories

# The project directory
projdir="/project/6006056/cwcharle/fir-hifiasm/"

# The scratch directory for hifiasm project results
assemblyscratch="/scratch/cwcharle/fir-hifiasm"

# The path where you would like the job output to be placed
out_dir_path="${assemblyscratch}/bwa"
log_archive_dir="${projdir}/copied_output_logs/bwa"

# The path to the hifiasm results folder

input_from_hifiasm="/scratch/cwcharle/fir-hifiasm/2026-Oct-19_15-35-12"

hap1_name="hifiasm.asm.hic.hap1.p_ctg.gfa"

hap2_name="hifiasm.asm.hic.hap2.p_ctg.gfa"

# The path to and names of the Hi-C Reads
hic_R1_path="/home/cwcharle/project/gw2022_data/HiC_raw_reads"
hic_R1_name="P_trochiloides.HiC.R1.fq.gz"

hic_R2_path=${hic_R1_path}
hic_R2_name="P_trochiloides.HiC.R2.fq.gz"

# Path to HiC utils
utils_path="/project/6006056/cwcharle/fir-hifiasm/HapHiC/utils"

# Path to locally installed gfatools
gfatoolspath="${projdir}/gfatools/"

# Copy input files to temp node local directory
# This makes reads/writes faster during the job

cp ${input_from_hifiasm}/${hap1_name} ${SLURM_TMPDIR}
cp ${input_from_hifiasm}/${hap2_name} ${SLURM_TMPDIR}

cp ${hic_R1_path}/${hic_R1_name} ${SLURM_TMPDIR}
cp ${hic_R2_path}/${hic_R2_name} ${SLURM_TMPDIR}

printf "\nThe files in SLURM_TMPDIR are:\n"
echo $(ls ${SLURM_TMPDIR})

# Change working directory to the temp node local directory
# This is just so we can use smaller file paths and all outputs
# are generated on the node

mkdir ${SLURM_TMPDIR}/${jobtime}

printf "\nChanging working directory to job directory within SLURM_TMPDIR\n"
cd ${SLURM_TMPDIR}/${jobtime}

# Extracting fastas from .gfas for both haplotypes
printf "Creating fastas from assembly graphs"
${gfatoolspath}/gfatools gfa2fa ../${hap1_name} > ../hap1.fa
${gfatoolspath}/gfatools gfa2fa ../${hap2_name} > ../hap2.fa

# Concatenating fastas
printf "\nConcatenating fastas for the two haplotypes\n"

cat ../hap1.fa ../hap2.fa > ../both_haps.fa

printf "\nThe files in SLURM_TMPDIR are:\n"
echo $(ls ${SLURM_TMPDIR})

# Run bwa

printf "\nIndexing the fasta with bwa index\n"

bwa index ../both_haps.fa

printf "\nThe files in SLURM_TMPDIR are:\n"
echo $(ls ${SLURM_TMPDIR})

printf "\nRunning bwa-mem, samblaster, and samtools\n"

bwa mem \
-5SP \
-t 28 \
../both_haps.fa \
../${hic_R1_name} \
../${hic_R2_name} \
| samblaster \
| samtools view - \
-@ 28 \
-S \
-h \
-b \
-F 3340 \
-o ./HiC.bam

printf "\nRunning HiC utils filter_bam\n"
${utils_path}/filter_bam \
HiC.bam 1 \
--nm 3 \
--threads 28 \
| samtools view - \
-b \
-@ 28 \
-o ./HiC_filtered.bam

# Move output back to output directory in projects directory

printf "\nCopying final output file back to projects directory in ${out_dir_path}\n"

mkdir -p ${out_dir_path}/

mkdir -p ${log_archive_dir}/

cp -r ${SLURM_TMPDIR}/${jobtime} ${out_dir_path}/

printf "\n These are the files in the output directory\n"
ls ${out_dir_path}

printf "\n Moving logfile to the output folder \n"
mv ${init_wd}/${log_filename} ${out_dir_path}/${jobtime}

printf "\n Copying logfile to the archive folder \n"
cp ${out_dir_path}/${jobtime}/${log_filename} ${log_archive_dir}

printf "\nScript complete\n"
