#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=28
#SBATCH --mem=128G
#SBATCH --job-name="make_tracks.sub.sh"
#SBATCH --account=def-dirwin
#SBATCH --output=job_%j.out
#SBATCH --mail-user=cwc@zoology.ubc.ca
#SBATCH --mail-type=ALL

# Setting initial variables

scratchpath="/home/cwcharle/scratch"

this_filename="make_tracks.sub.sh"

prologue_filename="tools/single_job_prologue.sh"

# Run prologue script to take care of some logging and synchronize jobtimes
source ${prologue_filename}

# Load modules
printf "\nCurrently loaded modules\n"
module list

module load \
bwa-mem2/2.2.1 \
samblaster/0.1.26 \
samtools/1.22.1 \
minimap2/2.31 \
bedtools/2.31.1

printf "\nCurrently loaded modules\n"
module list

# Create variables with paths and names of input and output files
# This is the last spot where you need to ADD VARIABLES (3/3)

# The path where you would like the job output to be placed
out_dir_path="/home/cwcharle/scratch/fir-hifiasm/make_tracks"
log_archive_dir="/home/cwcharle/projects/def-dirwin/cwcharle/fir-hifiasm/copied_output_logs/make_tracks"

# The path to the new scaffold from haphic (or just assembly) to map sequences to

#input_from_haphic="/scratch/cwcharle/fir-hifiasm/HapHiC/"

#scaffold_name="scaffolds.fa"

input_from_hifiasm="/home/cwcharle/scratch/fir-hifiasm/hifiasm/2026-Oct-19_15-35-12"

hap1_name="hifiasm.asm.hic.hap1.p_ctg.gfa"

hap2_name="hifiasm.asm.hic.hap2.p_ctg.gfa"

# The path to Pacbio HiFi reads to map to the new scaffold for coverage track

pacbio_dir="/project/6006056/cwcharle/gw2022_data/HiFi_raw_reads"
pacbio_name="P_trochiloides.HiFi.cells_concat.fasta"

# The path to and names of the Hi-C 

# Path to HiC utils
utils_path="/project/6006056/cwcharle/fir-hifiasm/HapHiC/utils"

# Path to locally installed gfatools
gfatoolspath="${projdir}/gfatools/"

# Copy input files to temp node local directory
# This makes reads/writes faster during the job

#cp ${input_from_haphic}/${scaffold_name} ${SLURM_TMPDIR}

cp ${input_from_hifiasm}/${hap1_name} ${SLURM_TMPDIR}
cp ${input_from_hifiasm}/${hap2_name} ${SLURM_TMPDIR}

cp ${pacbio_dir}/${pacbio_name} ${SLURM_TMPDIR}

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

# Run minimap
printf "\nRunning minimap2 to create coverage track\n"

minimap2 \
-t 27 \
-ax \
map-hifi \
../both_haps.fa \
../${pacbio_name} \
> hifi_coverage.sam

# Use tools to create coverage and gap tracks
samtools view -b hifi_coverage.sam > hifi_coverage.bam
samtools sort hifi_coverage.bam > hifi_coverage.sorted.bam
bedtools genomecov -bga -ibam hifi_coverage.sorted.bam > hifi_coverage.sorted.bga
grep -w 0$ hifi_coverage.sorted.bga | sed 's/0$/200/g' > hifi_coverage.sorted.gaps.bga

# Move files to the output directory
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
