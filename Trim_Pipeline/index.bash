#!/bin/bash
#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=index            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e index-%j.err             # Error file for this job.
#SBATCH -o index-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr     # Project allocation account name (REQUIRED)

cd /scratch/jwme229/host_contam_rmvl ;

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

conda activate hocort

mkdir GRCh38_p14 ;

hocort index bowtie2 --input GCF_000001405.40_GRCh38.p14_genomic.fasta --output /scratch/jwme229/host_contam_rmvl/GRCh38_p14 ;

conda deactivate

