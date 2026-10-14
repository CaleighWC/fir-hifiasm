#!/bin/bash

#SBATCH --time=0-05:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --job-name="pretextmap.sub.sh"
#SBATCH --account=def-dirwin
#SBATCH --output=job_%j.out
#SBATCH --mail-user=cwc@zoology.ubc.ca
#SBATCH --mail-type=ALL

# Setting initial variables

scratchpath="/home/cwcharle/scratch"

this_filename="pretextmap.sub.sh"

prologue_filename="tools/single_job_prologue.sh"

# Run prologue script to take care of some logging and synchronize jobtimes
source ${prologue_filename}

# Load modules
printf "\nCurrently loaded modules\n"
module list

module load \
samtools/1.22.1

printf "\nCurrently loaded modules\n"

# Create variables for input and output files

# The path where you would like the job output to be placed
out_dir_path="/home/cwcharle/scratch/fir-hifiasm/pretextmap"
log_archive_dir="/home/cwcharle/projects/def-dirwin/cwcharle/fir-hifiasm/copied_output_logs/pretextmap"

# The path to the new bwa alignment for the contact map
aln_path="/scratch/cwcharle/fir-hifiasm/bwa/2026-Sep-15_15-17-14"
aln_name="HiC_filtered.bam"

# The path to the PretextMap script directory
pretextmap_loc="/project/6006056/cwcharle/fir-hifiasm/PretextMap/builddir"

# Copy input files to temp node local directory
# This makes reads/writes faster during the job

cp ${aln_path}/${aln_name} ${SLURM_TMPDIR}

printf "\nThe files in SLURM_TMPDIR are:\n"
echo $(ls ${SLURM_TMPDIR})

# Change working directory to the temp node local directory
# This is just so we can use smaller file paths and all outputs
# are generated on the node

mkdir ${SLURM_TMPDIR}/${jobtime}

printf "\nChanging working directory to job directory within SLURM_TMPDIR\n"
cd ${SLURM_TMPDIR}/${jobtime}

# Run pretextmap
printf "\nRunning PretextMap\n"

samtools view -h ../${aln_name} \
| ${pretextmap_loc}/PretextMap \
-o defaultRes.pretext \

# resolution options are --highRes or --ultraRes

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
