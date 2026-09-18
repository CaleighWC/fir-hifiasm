#!/bin/bash

#SBATCH --time=0-00:005:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --job-name="hifiasm.sub.sh"
#SBATCH --account=def-dirwin
#SBATCH --output=job_%j.out
#SBATCH --mail-user=cwc@zoology.ubc.ca
#SBATCH --mail-type=ALL

# Setting initial variables

scratchpath="/home/cwcharle/scratch"

this_filename="hifiasm.sub.sh"

prologue_filename="tools/single_job_prologue.sh"

# Run prologue script to take care of some logging and synchronize jobtimes
source ${prologue_filename}

# Load modules
printf "\nCurrently loaded modules\n"
module list

module load \
python/3.12.4

printf "\nCurrently loaded modules\n"
module list

# Create variables with paths and names of input and output files
# This is the last spot where you need to ADD VARIABLES (3/3)

# The path where you would like the job output to be placed
out_dir_path="/home/cwcharle/scratch/fir-hifiasm/HapHiC"
log_archive_dir="/home/cwcharle/projects/def-dirwin/cwcharle/fir-hifiasm/copied_output_logs/HapHiC"

# The path to and names of the two haplotype fasta files extracted from .gfas
fasta_path="/scratch/cwcharle/fir-hifiasm/2026-Aug-31_22-33-37"
fasta_hap1_name="hifiasm.asm.hic.hap1.p_ctg.fasta"
fasta_hap2_name="hifiasm.asm.hic.hap2.p_ctg.fasta"

# The path to and names of the two 
graph_path=${fasta_path}
graph_hap1_name="hifiasm.asm.hic.hap1.p_ctg.gfa"
graph_hap2_name="hifiasm.asm.hic.hap2.p_ctg.gfa"

# The path to the HapHiC script directory
haphic_loc="/home/cwcharle/project/fir-hifiasm/HapHiC"

# The path to and names of the alignment between HiC reads and the concatenated fasta
hic_aln_path="/scratch/cwcharle/fir-hifiasm/bwa/2026-Sep-15_15-17-14"
hic_aln_name="HiC_filtered.bam"

# Copy input files to temp node local directory
# This makes reads/writes faster during the job

cp ${fasta_path}/${fasta_hap1_name} ${SLURM_TMPDIR}
cp ${fasta_path}/${fasta_hap2_name} ${SLURM_TMPDIR}

cp ${graph_path}/${graph_hap1_name} ${SLURM_TMPDIR}
cp ${graph_path}/${graph_hap2_name} ${SLURM_TMPDIR}

cp ${hic_aln_path}/${hic_aln_name} ${SLURM_TMPDIR}

printf "\nThe files in SLURM_TMPDIR are:\n"
echo $(ls ${SLURM_TMPDIR})

# Change working directory to the temp node local directory
# This is just so we can use smaller file paths and all outputs
# are generated on the node

mkdir ${SLURM_TMPDIR}/${jobtime}

printf "\nChanging working directory to job directory within SLURM_TMPDIR\n"
cd ${SLURM_TMPDIR}/${jobtime}

printf "\nConcatenating fastas\n"

cat ../${fasta_hap1_name} ../${fasta_hap2_name} > ../haps_concat.fa

printf "\nLoading Python virtual environment\n"

source ${haphic_loc}/haphic_env/bin/activate

printf "\nChecking HapHiC dependencies\n"

${haphic_loc}/haphic check

# Run HapHiC
printf "\nRunning HapHiC\n"

${haphic_loc}/haphic pipeline \
../haps_concat.fa \
../${hic_aln_path} \
1 \
--gfa "../${graph_hap1_name},../${graph_hap2_name}" \
--quick_view \
--threads 8 \
--processes 8

# Move output back to output directory in projects directory

printf "\nCopying final output file back to projects directory in ${out_dir_path}\n"

mkdir -p ${out_dir_path}/

cp -r ${SLURM_TMPDIR}/${jobtime} ${out_dir_path}/

printf "\n These are the files in the output directory\n"
ls ${out_dir_path}

printf "\n Moving logfile to the output folder \n"
mv ${init_wd}/${log_filename} ${out_dir_path}/${jobtime}

printf "\n Copying logfile to the archive folder \n"
cp ${out_dir_path}/${jobtime}/${log_filename} ${log_archive_dir}

printf "\nScript complete\n"
