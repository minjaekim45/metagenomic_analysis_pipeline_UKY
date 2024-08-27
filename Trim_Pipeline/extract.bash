#!/bin/bash
#SBATCH --time=06:00:00               # Time limit for the job (REQUIRED).
#SBATCH --job-name=extract            # Job name
#SBATCH --ntasks=4                    # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal            # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e extract-%j.err             # Error file for this job.
#SBATCH -o extract-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr     # Project allocation account name (REQUIRED)

cd /scratch/jwme229/host_contam_rmvl

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

conda activate sra-tools

fasterq-dump SRR18498477 --split-files

conda deactivate
