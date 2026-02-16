#!/bin/bash
#SBATCH --time=18:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=Functional_profiling_step3           # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e 36.Functional_profiling-step3-%j.err             # Error file for this job.
#SBATCH -o 36.Functional_profiling-step3-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --mem=10G

set -euo pipefail

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate python

# Update this path to your Pfam-A.hmm
PFAM_HMM="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/databases/Pfam-A.hmm"

python3 scripts/step3_pfam_validation.py \
  --pfam_hmm "${PFAM_HMM}" \
  --functional_dir FASTQ/fastq_files/36.functionalprofiling \
  --bakta_root FASTQ/fastq_files/11.bakta/results \
  --metabolisms propionate,butyrate,acetate \
  --cpu 8 \
  --threshold 0.75 \
  --evalue_pass 1e-5 \
  --cov_pass 0.60 \
  --cov_hold 0.40
