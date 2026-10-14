#!/bin/bash

#SBATCH --time=13:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --job-name="genome_mode_busco"
#SBATCH --account=def-dirwin
#SBATCH --output=job_%j.out
#SBATCH --mail-user=cwc@zoology.ubc.ca
#SBATCH --mail-type=ALL 

# Set jobtime so dates on different outputs from the job will match

jobtime=$(date "+%Y-%b-%d_%H-%M-%S")

# Move output file to have jobtime in it

mv job_${SLURM_JOB_ID}.out job_${SLURM_JOB_ID}_${jobtime}.out

# Load apptainer (dependency for inparanoid)

printf "Currently loaded modules"
module list

printf "Loading modules for job"
module load \
StdEnv/2023 \
apptainer/1.3.4

printf "Currently loaded modules"
module list

# Create variables with paths and names of input files

dbpath='/scratch/cwcharle/busco_downloads/lineages'
dbname='passeriformes_odb10'

genomepath='/home/cwcharle/project/fir-hifiasm/results/2026-Aug-31_22-33-37'
genomename='hifiasm.asm.hic.combined.p_ctg.fasta'
genomename2='hifiasm.asm.hic.hap2.p_ctg.fasta'

contpath='/home/cwcharle/projects/def-dirwin/cwcharle/annotation-prep/'
contname='busco_v5.8.0_cv1.sif'

# Copy input files to temp node local directory as input and make working directory

#cp ${dbpath}/${dbname}${dbext} ${SLURM_TMPDIR}

cp ${genomepath}/${genomename} ${SLURM_TMPDIR} 
cp ${genomepath}/${genomename2} ${SLURM_TMPDIR}

cp ${contpath}/${contname} ${SLURM_TMPDIR}

cp -r ${dbpath}/${dbname} ${SLURM_TMPDIR}

printf "The files in SLURM_TMPDIR are:"
echo $(ls ${SLURM_TMPDIR})

# Make node local output directory to copy back later

mkdir ${SLURM_TMPDIR}/output

# Run busco and write its output to the node local output

cd ${SLURM_TMPDIR}

#tar -xf ${SLURM_TMPDIR}/${dbname}${dbext} # Extract database

printf "Attempting to run busco"

apptainer run \
-C \
-B ${SLURM_TMPDIR}:/busco_wd \
-W ${SLURM_TMPDIR} \
--compat \
--cwd /busco_wd \
busco_v5.8.0_cv1.sif \
busco \
-i ${genomename} \
-m genome \
-l ./${dbname} \
-c 8 \
-o ${jobtime}/hap_1

#apptainer run \
#-C \
#-B ${SLURM_TMPDIR}:/busco_wd \
#-W ${SLURM_TMPDIR} \
#--compat \
#--cwd /busco_wd \
#busco_v5.8.0_cv1.sif \
#busco \
#-i ${genomename2} \
#-m genome \
#-l ./${dbname} \
#-c 8 \
#-o ${jobtime}/hap_2

printf "busco run finished"

printf "The files in SLURM_TMPDIR are now"
echo $(ls ${SLURM_TMPDIR})

# Move output back to new output directory in projects directory

out_dir_path='/home/cwcharle/project/fir-hifiasm/results/busco/'
mkdir -p ${out_dir_path}
cp -r ${SLURM_TMPDIR}/${jobtime} ${out_dir_path}

