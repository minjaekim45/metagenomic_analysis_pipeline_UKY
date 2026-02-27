#!/bin/bash
#SBATCH --time=18:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=Functional_profiling_1st           # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e 36.Functional_profiling-MAGs-%j.err             # Error file for this job.
#SBATCH -o 36.Functional_profiling-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --mem=10G

set -euo pipefail

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate python

python3 scripts/step1_screen_candidates_by_kos.py \
  --gene_set_tsv scripts/gene_sets_step1.tsv \
  --eggnog_root FASTQ/fastq_files/34.eggnog \
  --outdir FASTQ/fastq_files/36.functionalprofiling \
  --metabolisms Propionate,Butyrate,Acetate \
  --thresholds Acetate=0.75,Butyrate=1.0,Propionate=1.0 \
  --gene_presence_threshold 0.4
