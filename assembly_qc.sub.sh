#!/bin/bash

#SBATCH --time=0-03:00:00
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
apptainer/1.3.4

printf "Currently loaded modules"
module list

# Create variables with paths and names of input files

## Directory paths

# The project directory
projdir="/project/6006056/cwcharle/fir-hifiasm/"

# The scratch directory for hifiasm project results
assemblyscratch="/scratch/cwcharle/fir-hifiasm"

# The path where you would like the job output to be placed
out_dir_path="${assemblyscratch}/assembly_qc"
log_archive_dir="${projdir}/copied_output_logs"

## Input files

# The genome assembly graphs
genomepath="${assemblyscratch}/hifiasm/2026-Oct-19_15-35-12/"
hap1_name='hifiasm.asm.hic.hap1.p_ctg.gfa'
hap2_name='hifiasm.asm.hic.hap2.p_ctg.gfa'

# Raw reads to compare assembly k-mer spectra against
reads_path="/project/6006056/cwcharle/gw2022_data/HiFi_raw_reads"
reads_name="P_trochiloides.HiFi.cells_concat.fasta"

## BUSCO and KAT tools

# The Busco database
dbpath='/scratch/cwcharle/busco_downloads/lineages'
dbname='passeriformes_odb10'

# The busco container
buscopath='/home/cwcharle/projects/def-dirwin/cwcharle/annotation-prep/'
busconame='busco_v5.8.0_cv1.sif'

# The KAT container
katpath="${projdir}"
katname='kat_2.4.2--py39he0b6574_5.sif'

# gfatools install location
gfatoolspath="${projdir}/gfatools/"

# Copy input files to temp node local directory as input and make working directory

cp ${genomepath}/${hap1_name} ${SLURM_TMPDIR} 
cp ${genomepath}/${hap2_name} ${SLURM_TMPDIR}

cp ${buscopath}/${busconame} ${SLURM_TMPDIR}

cp -r ${dbpath}/${dbname} ${SLURM_TMPDIR}

printf "The files in SLURM_TMPDIR are:"
echo $(ls ${SLURM_TMPDIR})

# Make node local output directory to copy back later

subdir=${jobtime}_${SLURM_JOB_ID}
mkdir ${SLURM_TMPDIR}/${subdir}

# Change working directory to node-local directory

cd ${SLURM_TMPDIR}

# Run gfatools from local install for stats and extract fastas

printf "Printing stats of graphs to files"
${gfatoolspath}/gfatools stat ${hap1_name} > ${subdir}/hap1_gfastats.txt
${gfatoolspath}/gfatools stat ${hap2_name} > ${subdir}/hap2_gfastats.txt

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
${busconame} \
busco \
-i hap1.fa \
-m genome \
-l ./${dbname} \
-c 8 \
-o ${subdir}/busco_hap1

printf "\nRunning busco on hap2\n"

apptainer run \
-C \
-B ${SLURM_TMPDIR}:/busco_wd \
-W ${SLURM_TMPDIR} \
--compat \
--cwd /busco_wd \
${busconame} \
busco \
-i hap2.fa \
-m genome \
-l ./${dbname} \
-c 8 \
-o ${subdir}/busco_hap2

printf "\nRunning busco on combined fasta\n"

apptainer run \
-C \
-B ${SLURM_TMPDIR}:/busco_wd \
-W ${SLURM_TMPDIR} \
--compat \
--cwd /busco_wd \
${busconame} \
busco \
-i haps_concat.fa \
-m genome \
-l ./${dbname} \
-c 8 \
-o ${subdir}/busco_combined

printf "\nDeleting file with all busco sequences to save space\n"
find . -type d -name "run_passeriformes_odb10" -prune -exec rm -rf {} +

printf "\nDone running busco\n"

printf "The files in SLURM_TMPDIR are now"
echo $(ls ${SLURM_TMPDIR})

printf "\nStarting to run KAT\n"

# Set hash parameters for raw reads and assembly
read_hash=1625081002
assembly_hash=1300000000

printf "\nRunning KAT tools on hap1\n"

# Set id to hap1

input_id="hap1"

printf "\nRunning KAT comp on ${input_id}\n"

apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat comp \
--threads 8 \
--hash_size_1 ${read_hash} \ 
--hash_size_2 ${assembly_hash} \
-o ${subdir}/raw_vs_assmbly_${input_id} \
--verbose \
--output_hists \
${reads_name} \
${input_id}.fa

printf "\nRunning KAT plot density on ${input_id}\n"
apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat plot density \
--x_max 10000 \
--output ${subdir}/kat_density_${input_id}.mx.pdf \
${subdir}/raw_vs_assmbly_${input_id}.mx

printf "\nRunning KAT cold on ${input_id}\n"
apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat cold \
--threads 8 \
--verbose \
--hash_size ${read_hash} \
--output_prefix ${subdir}/kat_cold_${input_id} \
${input_id}.fa \
${reads_name}

# Set id to hap2
input_id="hap2"
printf "\nRunning KAT comp on ${input_id}\n"

apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat comp \
--threads 8 \
--hash_size_1 ${read_hash} \
--hash_size_2 ${assembly_hash} \
-o ${subdir}/raw_vs_assmbly_${input_id} \
--verbose \
--output_hists \
${reads_name} \
${input_id}.fa

printf "\nRunning KAT plot density on ${input_id}\n"
apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat plot density \
--x_max 10000 \
--output ${subdir}/kat_density_${input_id}.mx.pdf \
${subdir}/raw_vs_assmbly_${input_id}.mx

printf "\nRunning KAT cold on ${input_id}\n"
apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat cold \
--threads 8 \
--verbose \
--hash_size ${read_hash} \
--output_prefix ${subdir}/kat_cold_${input_id} \
${input_id}.fa \
${reads_name}

# Set id to concatenated
input_id="haps_concat"
printf "\nRunning KAT comp on ${input_id}\n"

apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat comp \
--threads 8 \
--hash_size_1 ${read_hash} \
--hash_size_2 ${assembly_hash} \
-o ${subdir}/raw_vs_assmbly_${input_id} \
--verbose \
--output_hists \
${reads_name} \
${input_id}.fa

printf "\nRunning KAT plot density on ${input_id}\n"
apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat plot density \
--x_max 10000 \
--output ${subdir}/kat_density_${input_id}.mx.pdf \
${subdir}/raw_vs_assmbly_${input_id}.mx

printf "\nRunning KAT cold on ${input_id}\n"
apptainer exec \
kat_2.4.2--py39he0b6574_5.sif \
kat cold \
--threads 8 \
--verbose \
--hash_size ${read_hash} \
--output_prefix ${subdir}/kat_cold_${input_id} \
${input_id}.fa \
${reads_name}

printf "\nDone running KAT\n"

printf "\nMoving output back to new output directory in results location\n"

mkdir -p ${out_dir_path}
cp -r ${SLURM_TMPDIR}/${subdir} ${out_dir_path}

printf "\n Moving logfile to the output folder \n"
mv ${init_wd}/${log_filename} ${out_dir_path}/${subdir}

printf "\n Copying logfile to the archive folder \n"
cp ${out_dir_path}/${subdir}/${log_filename} ${log_archive_dir}

