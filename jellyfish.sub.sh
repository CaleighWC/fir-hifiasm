#!/bin/bash

#SBATCH --time=0-03:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --job-name="jellyfish"
#SBATCH --account=def-dirwin
#SBATCH --output=job_%j.out
#SBATCH --mail-user=cwc@zoology.ubc.ca
#SBATCH --mail-type=ALL 

# Setting initial variables

scratchpath="/home/cwcharle/scratch"

this_filename="jellyfish.sub.sh"

prologue_filename="tools/single_job_prologue.sh"

# Run prologue script to take care of some logging and synchronize jobtimes
source ${prologue_filename}

# Load modules

printf "Currently loaded modules"
module list

printf "Loading modules for job"
module load \
StdEnv/2023 \
jellyfish/2.3.1

printf "Currently loaded modules"
module list

# Create variables with paths and names of input files

# The path where you would like the job output to be placed
out_dir_path="/home/cwcharle/scratch/fir-hifiasm/jellyfish"
log_archive_dir="/home/cwcharle/projects/def-dirwin/cwcharle/fir-hifiasm/copied_output_logs/jellyfish"

# The genome assembly graphs
genomepath='/project/6006056/cwcharle/gw2022_data/HiFi_raw_reads'
genomename='P_trochiloides.HiFi.cells_concat.fasta'

# Copy input files to temp node local directory as input and make working directory

cp ${genomepath}/${genomename} ${SLURM_TMPDIR} 

printf "The files in SLURM_TMPDIR are:"
echo $(ls ${SLURM_TMPDIR})

# Make node local output directory to copy back later

subdir=${jobtime}_${SLURM_JOB_ID}
mkdir ${SLURM_TMPDIR}/${subdir}

# Change working directory to node-local directory

cd ${SLURM_TMPDIR}

# Run jellyfish on input genome

printf "\nRunning jellyfish on ${genomename}\n"

jellyfish count \
-m 22 \
-s 1300000000 \
-t 8 \
-C \
${genomename} \
-o ${subdir}/${genomename}.jf

printf "\nRunning jellyfish histo on ${genomename}\n"
jellyfish histo \
${subdir}/${genomename}.jf \
> ${subdir}/${genomename}.histo

printf "\nDone running jellyfish\n"

printf "\nMoving output back to new output directory in results location\n"

mkdir -p ${out_dir_path}
cp -r ${SLURM_TMPDIR}/${subdir} ${out_dir_path}

printf "\n Moving logfile to the output folder \n"
mv ${init_wd}/${log_filename} ${out_dir_path}/${subdir}

printf "\n Copying logfile to the archive folder \n"
mkdir -p ${log_archive_dir}
cp ${out_dir_path}/${subdir}/${log_filename} ${log_archive_dir}

