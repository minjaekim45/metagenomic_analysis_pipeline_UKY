#!/bin/bash
#SBATCH --time=18:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=Functional_profiling_step2           # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e 36.Functional_profiling-step2-%j.err             # Error file for this job.
#SBATCH -o 36.Functional_profiling-step2-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --mem=10G

set -euo pipefail

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate python

python3 scripts/step2_extract_bakta_evidence.py \
  --gene_set_tsv scripts/gene_sets_step1.tsv \
  --candidate_dir FASTQ/fastq_files/36.functionalprofiling \
  --eggnog_root FASTQ/fastq_files/34.eggnog \
  --bakta_root FASTQ/fastq_files/11.bakta/results \
  --out_root FASTQ/fastq_files/36.functionalprofiling \
  --metabolisms propionate,butyrate,acetate
