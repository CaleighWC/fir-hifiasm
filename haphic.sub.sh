#!/bin/bash

#SBATCH --time=0-09:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
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
out_dir_path="/home/cwcharle/scratch/fir-hifiasm/"
log_archive_dir="/home/cwcharle/projects/def-dirwin/cwcharle/fir-hifiasm/copied_output_logs"

# The path to and names of PacBio HiFi read fasta files
fasta_path="/home/cwcharle/projects/def-dirwin/cwcharle/gw2022_data/HiFi_raw_reads/"
#fasta_path="/home/cwcharle/projects/def-dirwin/cwcharle/gwstaffan_data/gwstaffan_raw_reads"

fasta_name="P_trochiloides.HiFi.cells_concat.fasta"
#fasta_name="staffan_gw_ref.hifi_reads.default.fasta"

haphic_loc="/home/cwcharle/project/fir-hifiasm/HapHiC"

# The path to and names of the Hi-C Reads
hifi_R1_path="/home/cwcharle/project/gw2022_data/HiC_raw_reads"
hifi_R1_name="P_trochiloides.HiC.R1.fq.gz"

hifi_R2_path=${hifi_R1_path}
hifi_R2_name="P_trochiloides.HiC.R2.fq.gz"

# Copy input files to temp node local directory
# This makes reads/writes faster during the job

cp ${fasta_path}/${fasta_name} ${SLURM_TMPDIR}

cp ${hifi_R1_path}/${hifi_R1_name} ${SLURM_TMPDIR}
cp ${hifi_R2_path}/${hifi_R2_name} ${SLURM_TMPDIR}

printf "\nThe files in SLURM_TMPDIR are:\n"
echo $(ls ${SLURM_TMPDIR})

# Change working directory to the temp node local directory
# This is just so we can use smaller file paths and all outputs
# are generated on the node

mkdir ${SLURM_TMPDIR}/${jobtime}

printf "\nChanging working directory to job directory within SLURM_TMPDIR\n"
cd ${SLURM_TMPDIR}/${jobtime}

printf "\nCreating python virtual environment\n"

# Make python virtual environment based on requirements
virtualenv \
--no-download \
$SLURM_TMPDIR/env
source $SLURM_TMPDIR/env/bin/activate
pip install --no-index --upgrade pip

pip install --no-index -r haphic_requirements.txt

# Run HapHiC

${haphic_loc}/haphic check



--h1 ../${hifi_R1_name} \
--h2 ../${hifi_R2_name} \
../${fasta_name}

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
