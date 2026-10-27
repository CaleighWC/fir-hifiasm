#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --job-name="assembly_qc"
#SBATCH --account=def-dirwin
#SBATCH --output=job_%j.out
#SBATCH --mail-user=cwc@zoology.ubc.ca
#SBATCH --mail-type=ALL 

# Setting initial variables

scratchpath="/home/cwcharle/scratch"

this_filename="assembly_qc.sub.sh"

prologue_filename="tools/single_job_prologue.sh"

# Run prologue script to take care of some logging and synchronize jobtimes
source ${prologue_filename}

# Load modules

printf "Currently loaded modules"
module list

printf "Loading modules for job"
module load \
StdEnv/2023 \
apptainer/1.3.4 \
jellyfish/2.3.1

printf "Currently loaded modules"
module list

# Create variables with paths and names of input files

# The path where you would like the job output to be placed
out_dir_path="/home/cwcharle/scratch/fir-hifiasm/assembly_qc"
log_archive_dir="/home/cwcharle/projects/def-dirwin/cwcharle/fir-hifiasm/copied_output_logs"

# The Busco database
dbpath='/scratch/cwcharle/busco_downloads/lineages'
dbname='passeriformes_odb10'

# The genome assembly graphs
genomepath='/scratch/cwcharle/fir-hifiasm/hifiasm/2026-Oct-19_15-35-12'
hap1_name='hifiasm.asm.hic.hap1.p_ctg.gfa'
hap2_name='hifiasm.asm.hic.hap2.p_ctg.gfa'

# The busco container
contpath='/home/cwcharle/projects/def-dirwin/cwcharle/annotation-prep/'
contname='busco_v5.8.0_cv1.sif'

# gfatools install location
gfatoolspath='/project/6006056/cwcharle/fir-hifiasm/gfatools/'

# Copy input files to temp node local directory as input and make working directory

cp ${genomepath}/${hap1_name} ${SLURM_TMPDIR} 
cp ${genomepath}/${hap2_name} ${SLURM_TMPDIR}

cp ${contpath}/${contname} ${SLURM_TMPDIR}

cp -r ${dbpath}/${dbname} ${SLURM_TMPDIR}

printf "The files in SLURM_TMPDIR are:"
echo $(ls ${SLURM_TMPDIR})

# Make node local output directory to copy back later

mkdir ${SLURM_TMPDIR}/${jobtime}

# Change working directory to node-local directory

cd ${SLURM_TMPDIR}

# Run gfatools for stats and extract fastas

printf "Printing stats of graphs to files"
${gfatoolspath}/gfatools stat ${hap1_name} > ${jobtime}/hap1_gfastats.txt
${gfatoolspath}/gfatools stat ${hap2_name} > ${jobtime}/hap2_gfastats.txt

printf "Creating fastas from assembly graphs"
${gfatoolspath}/gfatools gfa2fa ${hap1_name} > hap1.fa
${gfatoolspath}/gfatools gfa2fa ${hap2_name} > hap2.fa

printf "Creating concatenated fasta"
cat hap1.fa hap2.fa > haps_concat.fa

#tar -xf ${SLURM_TMPDIR}/${dbname}${dbext} # Extract database

printf "\nStarting to run busco\n"

printf "\nRunning busco on hap1\n"

apptainer run \
-C \
-B ${SLURM_TMPDIR}:/busco_wd \
-W ${SLURM_TMPDIR} \
--compat \
--cwd /busco_wd \
busco_v5.8.0_cv1.sif \
busco \
-i hap1.fa \
-m genome \
-l ./${dbname} \
-c 8 \
-o ${jobtime}/busco_hap1

printf "\nRunning busco on hap2\n"

apptainer run \
-C \
-B ${SLURM_TMPDIR}:/busco_wd \
-W ${SLURM_TMPDIR} \
--compat \
--cwd /busco_wd \
busco_v5.8.0_cv1.sif \
busco \
-i hap2.fa \
-m genome \
-l ./${dbname} \
-c 8 \
-o ${jobtime}/busco_hap2

printf "\nRunning busco on combined fasta\n"

apptainer run \
-C \
-B ${SLURM_TMPDIR}:/busco_wd \
-W ${SLURM_TMPDIR} \
--compat \
--cwd /busco_wd \
busco_v5.8.0_cv1.sif \
busco \
-i haps_concat.fa \
-m genome \
-l ./${dbname} \
-c 8 \
-o ${jobtime}/busco_combined

printf "\nDone running busco\n"

printf "The files in SLURM_TMPDIR are now"
echo $(ls ${SLURM_TMPDIR})

printf "\nStarting to run jellyfish\n"

printf "\nRunning jellyfish count on hap1\n"

jellyfish count \
-m 22 \
-s 1300000000 \
-t 8 \
-C hap1.fa \
-o ${jobtime}/hap1_mer_counts.jf

printf "\nRunning jellyfish histo on hap1\n"
jellyfish histo \
${jobtime}/hap1_mer_counts.jf \
> ${jobtime}/hap1_mer_counts.histo

printf "\nRunning jellyfish count on hap2\n"
jellyfish count \
-m 22 \
-s 1300000000 \
-t 8 \
-C hap2.fa \
-o ${jobtime}/hap2_mer_counts.jf

printf "\nRunning jellyfish histo on hap2\n"
jellyfish histo \
${jobtime}/hap2_mer_counts.jf \
> ${jobtime}/hap2_mer_counts.histo

printf "\nDone running jellyfish\n"

printf "\nMoving output back to new output directory in results location\n"

mkdir -p ${out_dir_path}
cp -r ${SLURM_TMPDIR}/${jobtime} ${out_dir_path}

printf "\n Moving logfile to the output folder \n"
mv ${init_wd}/${log_filename} ${out_dir_path}/${jobtime}

printf "\n Copying logfile to the archive folder \n"
cp ${out_dir_path}/${jobtime}/${log_filename} ${log_archive_dir}

